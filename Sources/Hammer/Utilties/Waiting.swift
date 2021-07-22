import Foundation
import UIKit

extension EventGenerator {
    /// Waits for a specified time.
    ///
    /// - parameter interval: The maximum time to wait.
    ///
    /// - throws: An error if there was an issue during waiting.
    public func wait(_ interval: TimeInterval) throws {
        CFRunLoopRunInMode(CFRunLoopMode.defaultMode, interval, false)
    }

    /// Waits for a condition to become true within the specified time.
    ///
    /// - parameter condition:     The condition to check.
    /// - parameter timeout:       The maximum time to wait for the condition to become true.
    /// - parameter checkInterval: How often should the condition be checked.
    ///
    /// - throws: An error if the condition did not return true within the specified time.
    public func waitUntil(_ condition: @autoclosure @escaping () throws -> Bool,
                          timeout: TimeInterval, checkInterval: TimeInterval = 0.1) throws
    {
        let startTime = Date().timeIntervalSinceReferenceDate
        while try !condition() {
            if Date().timeIntervalSinceReferenceDate - startTime > timeout {
                throw HammerError.waitConditionTimeout(timeout)
            }

            try self.wait(checkInterval)
        }
    }

    /// Waits for a closure to return non-nil within the specified time.
    ///
    /// - parameter exists:        The closure to check.
    /// - parameter timeout:       The maximum time to wait for the closure to return an object.
    /// - parameter checkInterval: How often should the closure be checked.
    ///
    /// - throws: An error if the closure did not return an object within the specified time.
    ///
    /// - returns: The non-nil object.
    @discardableResult
    public func waitUntilExists<T>(_ exists: @autoclosure @escaping () throws -> T?,
                                   timeout: TimeInterval, checkInterval: TimeInterval = 0.1) throws -> T
    {
        let startTime = Date().timeIntervalSinceReferenceDate
        while true {
            if let element = try exists() {
                return element
            }

            if Date().timeIntervalSinceReferenceDate - startTime > timeout {
                throw HammerError.waitConditionTimeout(timeout)
            }

            try self.wait(checkInterval)
        }
    }

    /// Waits for a view with the specified identifier to exist within the specified time.
    ///
    /// - parameter accessibilityIdentifier: The identifier of the view to wait for.
    /// - parameter timeout:                 The maximum time to wait for the view to be visible.
    /// - parameter checkInterval:           How often should the view be checked.
    ///
    /// - throws: An error if the view does not exist after the specified time.
    public func waitUntilExists(_ accessibilityIdentifier: String,
                                timeout: TimeInterval, checkInterval: TimeInterval = 0.1) throws
    {
        try self.waitUntilExists(self.viewWithIdentifier(accessibilityIdentifier),
                      timeout: timeout, checkInterval: checkInterval)
    }

    /// Waits for a view with the specified identifier to be visible within the specified time.
    ///
    /// - parameter accessibilityIdentifier: The identifier of the view to wait for.
    /// - parameter visibility:              How determine if the view is visible.
    /// - parameter timeout:                 The maximum time to wait for the view to be visible.
    /// - parameter checkInterval:           How often should the view be checked.
    ///
    /// - throws: An error if the view does not exist after the specified time.
    public func waitUntilVisible(_ accessibilityIdentifier: String, visibility: Visibility = .partial,
                                 timeout: TimeInterval, checkInterval: TimeInterval = 0.1) throws
    {
        try self.waitUntil(self.viewIsVisible(accessibilityIdentifier, visibility: visibility),
                           timeout: timeout, checkInterval: checkInterval)
    }

    /// Waits for a view with the specified identifier to be visible within the specified time.
    ///
    /// - parameter view:          The view to wait for.
    /// - parameter visibility:    How determine if the view is visible.
    /// - parameter timeout:       The maximum time to wait for the view to be visible.
    /// - parameter checkInterval: How often should the view be checked.
    ///
    /// - throws: An error if the view does not exist after the specified time.
    public func waitUntilVisible(_ view: UIView, visibility: Visibility = .partial,
                                 timeout: TimeInterval, checkInterval: TimeInterval = 0.1) throws
    {
        try self.waitUntil(self.viewIsVisible(view, visibility: visibility),
                           timeout: timeout, checkInterval: checkInterval)
    }

    /// Waits for a rect to be visible on screen within the specified time.
    ///
    /// - parameter rect:          The rect to wait for.
    /// - parameter visibility:    How determine if the view is visible.
    /// - parameter timeout:       The maximum time to wait for the rect to be visible.
    /// - parameter checkInterval: How often should the view be checked.
    ///
    /// - throws: An error if the rect is not visible within the specified time.
    public func waitUntilVisible(_ rect: CGRect, visibility: Visibility = .partial,
                                 timeout: TimeInterval, checkInterval: TimeInterval = 0.1) throws
    {
        try self.waitUntil(self.rectIsVisible(rect, visibility: visibility),
                           timeout: timeout, checkInterval: checkInterval)
    }

    /// Waits for a point to be visible on screen within the specified time.
    ///
    /// - parameter point:         The point to wait for.
    /// - parameter timeout:       The maximum time to wait for the point to be visible.
    /// - parameter checkInterval: How often should the view be checked.
    ///
    /// - throws: An error if the point is not visible within the specified time.
    public func waitUntilVisible(_ point: CGPoint,
                                 timeout: TimeInterval, checkInterval: TimeInterval = 0.1) throws
    {
        try self.waitUntil(self.pointIsVisible(point),
                           timeout: timeout, checkInterval: checkInterval)
    }

    /// Waits for a view with the specified identifier to be hittable within the specified time.
    ///
    /// - parameter accessibilityIdentifier: The identifier of the view to wait for.
    /// - parameter timeout:                 The maximum time to wait for the view to be hittable.
    /// - parameter checkInterval:           How often should the view be checked.
    ///
    /// - throws: An error if the view does not exist after the specified time.
    public func waitUntilHittable(_ accessibilityIdentifier: String,
                                  timeout: TimeInterval, checkInterval: TimeInterval = 0.1) throws
    {
        try self.waitUntil(self.viewIsHittable(accessibilityIdentifier),
                           timeout: timeout, checkInterval: checkInterval)
    }

    /// Waits for a view with the specified identifier to be hittable within the specified time.
    ///
    /// - parameter view:          The view to wait for.
    /// - parameter timeout:       The maximum time to wait for the view to be hittable.
    /// - parameter checkInterval: How often should the view be checked.
    ///
    /// - throws: An error if the view does not exist after the specified time.
    public func waitUntilHittable(_ view: UIView,
                                  timeout: TimeInterval, checkInterval: TimeInterval = 0.1) throws
    {
        try self.waitUntil(self.viewIsHittable(view),
                           timeout: timeout, checkInterval: checkInterval)
    }

    /// Waits for a point to be visible and hittable on screen within the specified time.
    ///
    /// - parameter point:         The point to wait for.
    /// - parameter timeout:       The maximum time to wait for the point to be hittable.
    /// - parameter checkInterval: How often should the view be checked.
    ///
    /// - throws: An error if the point is not hittable within the specified time.
    public func waitUntilHittable(_ point: CGPoint,
                                  timeout: TimeInterval, checkInterval: TimeInterval = 0.1) throws
    {
        try self.waitUntil(self.pointIsHittable(point),
                           timeout: timeout, checkInterval: checkInterval)
    }

    /// Waits for the default touch location to be visible and hittable on screen within the specified time.
    ///
    /// - parameter timeout:       The maximum time to wait for the point to be hittable.
    /// - parameter checkInterval: How often should the view be checked.
    ///
    /// - throws: An error if the point is not hittable within the specified time.
    public func waitUntilHittable(timeout: TimeInterval, checkInterval: TimeInterval = 0.1) throws {
        try self.waitUntil(self.viewIsHittable(self.rootView()),
                           timeout: timeout, checkInterval: checkInterval)
    }
}
