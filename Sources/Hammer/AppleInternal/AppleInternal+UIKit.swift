import Foundation
import UIKit

@objc protocol UIApplicationPrivate: NSObjectProtocol {
    @objc(_enqueueHIDEvent:)
    func enqueue(_ event: IOHIDEvent)
}

@objc protocol UIWindowPrivate: NSObjectProtocol {
    @objc(_contextId)
    var contextId: UInt32 { get }
}

extension UIApplication {
    typealias HIDEventCallback = (_ event: IOHIDEvent) -> Void
    typealias UIEventCallback = (_ event: UIEvent) -> Void

    private static var hidEventCallbacks = [ObjectIdentifier: HIDEventCallback]()
    private static var uiEventCallbacks = [ObjectIdentifier: UIEventCallback]()

    @objc
    private func swizzledHandleHIDEvent(_ event: IOHIDEvent) {
        // Calling this really calls the original un-swizzled method
        self.swizzledHandleHIDEvent(event)

        UIApplication.hidEventCallbacks.values.forEach { $0(event) }
    }

    @objc
    private func swizzledSendEvent(_ event: UIEvent) {
        // Callbacks run before dispatch so they see the phases that came from the HID event
        UIApplication.uiEventCallbacks.values.forEach { $0(event) }

        // Calling this really calls the original un-swizzled method
        self.swizzledSendEvent(event)
    }

    private static let runOnce: () = {
        class_addProtocol(UIApplication.self, UIApplicationPrivate.self)
        class_addProtocol(UIWindow.self, UIWindowPrivate.self)

        UIApplication.exchange(NSSelectorFromString("_handleHIDEvent:"),
                               with: #selector(UIApplication.swizzledHandleHIDEvent(_:)))
        UIApplication.exchange(#selector(UIApplication.sendEvent(_:)),
                               with: #selector(UIApplication.swizzledSendEvent(_:)))
    }()

    private static func exchange(_ originalSelector: Selector, with swizzledSelector: Selector) {
        let originalMethod = class_getInstanceMethod(UIApplication.self, originalSelector)
        let swizzledMethod = class_getInstanceMethod(UIApplication.self, swizzledSelector)
        if let originalMethod = originalMethod, let swizzledMethod = swizzledMethod {
            method_exchangeImplementations(originalMethod, swizzledMethod)
        } else {
            preconditionFailure("Failed to swizzle \(originalSelector)")
        }
    }

    static func swizzle() {
        self.runOnce
    }

    static func register(_ object: ObjectIdentifier, hidEventCallback: @escaping HIDEventCallback,
                         uiEventCallback: @escaping UIEventCallback)
    {
        self.hidEventCallbacks.updateValue(hidEventCallback, forKey: object)
        self.uiEventCallbacks.updateValue(uiEventCallback, forKey: object)
    }

    static func unregister(_ object: ObjectIdentifier) {
        self.hidEventCallbacks.removeValue(forKey: object)
        self.uiEventCallbacks.removeValue(forKey: object)
    }
}

/// The queue UIKit uses to process keyboard input, such as inserting typed text.
enum KeyboardTaskQueue {
    /// Adds a task that runs once UIKit has processed all the keyboard input received so far. Runs the task
    /// right away when there is no active keyboard.
    ///
    /// - parameter task: The task to run.
    ///
    /// - throws: An error if the private API is not available.
    static func addTask(_ task: @escaping () -> Void) throws {
        guard let keyboardClass = NSClassFromString("UIKeyboardImpl") as AnyObject? else {
            throw HammerError.unableToAccessPrivateApi(type: "UIKeyboardImpl", method: "Class")
        }

        let activeInstanceSelector = NSSelectorFromString("activeInstance")
        guard keyboardClass.responds(to: activeInstanceSelector) else {
            throw HammerError.unableToAccessPrivateApi(type: "UIKeyboardImpl", method: "activeInstance")
        }

        guard let keyboard = keyboardClass.perform(activeInstanceSelector)?.takeUnretainedValue() else {
            task()
            return
        }

        let taskQueueSelector = NSSelectorFromString("taskQueue")
        let addTaskSelector = NSSelectorFromString("addTask:")
        guard keyboard.responds(to: taskQueueSelector),
              let taskQueue = keyboard.perform(taskQueueSelector)?.takeUnretainedValue(),
              taskQueue.responds(to: addTaskSelector) else
        {
            throw HammerError.unableToAccessPrivateApi(type: "UIKeyboardTaskQueue", method: "addTask:")
        }

        // The queue only moves on to the next task once this one returns execution to it
        let returnSelector = NSSelectorFromString("returnExecutionToParent")
        let block: @convention(block) (AnyObject) -> Void = { context in
            task()
            _ = context.perform(returnSelector)
        }

        _ = taskQueue.perform(addTaskSelector, with: unsafeBitCast(block, to: AnyObject.self))
    }
}
