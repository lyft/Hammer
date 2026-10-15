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

    private static var hidEventCallbacks = [ObjectIdentifier: HIDEventCallback]()

    @objc
    private func swizzledHandleHIDEvent(_ event: IOHIDEvent) {
        // Calling this really calls the original un-swizzled method
        self.swizzledHandleHIDEvent(event)

        UIApplication.hidEventCallbacks.values.forEach { $0(event) }
    }

    private static let runOnce: () = {
        class_addProtocol(UIApplication.self, UIApplicationPrivate.self)
        class_addProtocol(UIWindow.self, UIWindowPrivate.self)

        let originalMethod = class_getInstanceMethod(
            UIApplication.self, NSSelectorFromString("_handleHIDEvent:"))
        let swizzledMethod = class_getInstanceMethod(
            UIApplication.self, #selector(UIApplication.swizzledHandleHIDEvent(_:)))
        if let originalMethod = originalMethod, let swizzledMethod = swizzledMethod {
            method_exchangeImplementations(originalMethod, swizzledMethod)
        } else {
            preconditionFailure("Failed to swizzle _handleHIDEvent")
        }
    }()

    static func swizzle() {
        self.runOnce
    }

    static func registerForHIDEvents(_ object: ObjectIdentifier, callback: @escaping HIDEventCallback) {
        self.hidEventCallbacks.updateValue(callback, forKey: object)
    }

    static func unregisterForHIDEvents(_ object: ObjectIdentifier) {
        self.hidEventCallbacks.removeValue(forKey: object)
    }
}

/// The queue UIKit uses to process keyboard input, such as inserting typed text.
enum KeyboardTaskQueue {
    /// Waits until UIKit has processed all the keyboard input received so far. Returns immediately when
    /// there is no active keyboard.
    ///
    /// - throws: An error if the private API is not available.
    static func waitUntilAllTasksAreFinished() throws {
        guard let keyboardClass = NSClassFromString("UIKeyboardImpl") as AnyObject? else {
            throw HammerError.unableToAccessPrivateApi(type: "UIKeyboardImpl", method: "Class")
        }

        let activeInstanceSelector = NSSelectorFromString("activeInstance")
        guard keyboardClass.responds(to: activeInstanceSelector) else {
            throw HammerError.unableToAccessPrivateApi(type: "UIKeyboardImpl", method: "activeInstance")
        }

        guard let keyboard = keyboardClass.perform(activeInstanceSelector)?.takeUnretainedValue() else {
            return
        }

        let taskQueueSelector = NSSelectorFromString("taskQueue")
        let waitSelector = NSSelectorFromString("waitUntilAllTasksAreFinished")
        guard keyboard.responds(to: taskQueueSelector),
              let taskQueue = keyboard.perform(taskQueueSelector)?.takeUnretainedValue(),
              taskQueue.responds(to: waitSelector) else
        {
            throw HammerError.unableToAccessPrivateApi(type: "UIKeyboardTaskQueue",
                                                       method: "waitUntilAllTasksAreFinished")
        }

        _ = taskQueue.perform(waitSelector)
    }
}
