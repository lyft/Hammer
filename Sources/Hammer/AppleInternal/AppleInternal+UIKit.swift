import Foundation
import UIKit

@objc protocol UIApplicationPrivate: NSObjectProtocol {
    @objc(_enqueueHIDEvent:)
    func enqueue(_ event: IOHIDEvent)

    @objc(_touchesEvent)
    var touchesEvent: UIEvent { get }
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
