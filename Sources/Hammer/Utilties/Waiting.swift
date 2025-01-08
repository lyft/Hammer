import Foundation
import UIKit
import XCTest

extension EventGenerator {
    /// Object to handle waiting
    public final class Waiter {
        public enum State {
            case idle
            case running
            case completed(timeout: Bool)
        }

        /// The maximum time to wait before stopping itself
        public let timeout: TimeInterval

        /// The current state of the waiter
        public private(set) var state: State = .idle

        /// We use XCTestExpectations internally to sleep the execution in a way that is friendly to tests
        /// and does not block the main thread.
        private let expectation = XCTestExpectation(description: "Hammer-Wait")

        /// Initialize a Waiter
        ///
        /// - parameter timeout: The maximum time to wait before stopping itself
        public init(timeout: TimeInterval) {
            self.timeout = timeout
        }

        /// Begin waiting
        public func start() throws {
            if case .running = self.state {
                throw HammerError.waiterIsAlreadyRunning
            } else if case .completed = self.state {
                throw HammerError.waiterIsAlreadyCompleted
            }

            self.state = .running
            let result = XCTWaiter.wait(for: [self.expectation], timeout: self.timeout)
            switch result {
            case .completed:
                self.state = .completed(timeout: false)
            default:
                self.state = .completed(timeout: true)
            }
        }

        /// Stop waiting before the timeout
        public func complete() throws {
            if case .idle = self.state {
                throw HammerError.waiterIsNotRunning
            } else if case .completed = self.state {
                throw HammerError.waiterIsAlreadyCompleted
            }

            self.expectation.fulfill()
        }
    }

    /// Waits for a specified time.
    ///
    /// - parameter interval: The maximum time to wait.
    ///
    /// - throws: An error if there was an issue during waiting.
    public func wait(_ interval: TimeInterval) throws {
        try Waiter(timeout: interval).start()
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
        try self.waitUntil(self.viewIsHittable(self.mainView),
                           timeout: timeout, checkInterval: checkInterval)
    }

    // MARK: - System waiting

    /// Waits for the main runloop is flushed and all scheduled tasks have executed.
    ///
    /// - parameter timeout: The maximum time to wait.
    ///
    /// - throws: An error if the runloop is not flushed within the specified time.
    public func waitUntilRunloopIsFlushed(timeout: TimeInterval) throws {
        var errorCompleting: Error?

        let waiter = Waiter(timeout: timeout)
        DispatchQueue.main.async {
            do {
                try waiter.complete()
            } catch {
                errorCompleting = error
            }
        }

        try waiter.start()
        if let errorCompleting {
            throw errorCompleting
        }
    }
}
