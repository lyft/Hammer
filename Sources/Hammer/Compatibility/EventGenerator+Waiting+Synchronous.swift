import Foundation
import UIKit

// Synchronous versions of the async API, for tests that are not async.
extension EventGenerator {
    /// Object to handle waiting in synchronous code.
    @preconcurrency
    @MainActor
    public final class Waiter {
        public enum State: Sendable {
            case idle
            case running
            case completed(timeout: Bool)
        }

        /// The maximum time to wait before stopping itself
        public let timeout: TimeInterval

        /// The current state of the waiter
        public private(set) var state: State = .idle

        private var isCompleteRequested = false

        /// Initialize a Waiter
        ///
        /// - parameter timeout: The maximum time to wait before stopping itself
        public init(timeout: TimeInterval) {
            self.timeout = timeout
        }

        /// Begin waiting
        ///
        /// - parameter throwIfAlreadyCompleted: If true, throws an error if the waiter has already completed
        @available(*, noasync, message: "Await the async waiting methods instead")
        public func start(throwIfAlreadyCompleted: Bool = true) throws {
            if case .running = self.state {
                throw HammerError.waiterIsAlreadyRunning
            } else if case .completed = self.state {
                if throwIfAlreadyCompleted {
                    throw HammerError.waiterIsAlreadyCompleted
                } else {
                    return
                }
            }

            self.state = .running
            let isCompleted = MainRunLoop.run(until: { self.isCompleteRequested }, timeout: self.timeout)
            self.state = .completed(timeout: !isCompleted)
        }

        /// Stop waiting before the timeout
        public func complete() throws {
            if case .idle = self.state {
                throw HammerError.waiterIsNotRunning
            } else if case .completed = self.state {
                throw HammerError.waiterIsAlreadyCompleted
            }

            self.isCompleteRequested = true
        }
    }

    public func wait(_ interval: TimeInterval) throws {
        try Waiter(timeout: interval).start()
    }

    /// Waits for the condition closure to call complete on the waiter.
    ///
    /// - parameter condition: The condition to check.
    /// - parameter timeout:   The maximum time to wait, or nil to use `settings.waitTimeout`.
    ///
    /// - throws: An error if the condition did not complete within the specified time.
    @available(*, noasync, message: "Await the async waiting methods instead")
    public func waitUntil(_ condition: (Waiter) throws -> Void, timeout: TimeInterval? = nil) throws {
        let timeout = timeout ?? self.settings.waitTimeout
        let waiter = Waiter(timeout: timeout)
        try condition(waiter)
        try waiter.start(throwIfAlreadyCompleted: false)
        if case .completed(timeout: true) = waiter.state {
            throw HammerError.waitConditionTimeout(timeout)
        }
    }

    public func waitUntil(_ condition: @autoclosure @escaping () throws -> Bool,
                          timeout: TimeInterval? = nil) throws
    {
        try self.runSynchronously { try await self.waitUntil(try condition(), timeout: timeout) }
    }

    @discardableResult
    public func waitUntilExists<T>(_ exists: @autoclosure @escaping () throws -> T?,
                                   timeout: TimeInterval? = nil) throws -> T
    {
        try self.runSynchronously { try await self.waitUntilExists(try exists(), timeout: timeout) }
    }

    public func waitUntilExists(_ accessibilityIdentifier: String, timeout: TimeInterval? = nil) throws {
        try self.runSynchronously {
            try await self.waitUntilExists(accessibilityIdentifier, timeout: timeout)
        }
    }

    public func waitUntilVisible(_ accessibilityIdentifier: String, visibility: Visibility = .partial,
                                 timeout: TimeInterval? = nil) throws
    {
        try self.runSynchronously {
            try await self.waitUntilVisible(accessibilityIdentifier, visibility: visibility, timeout: timeout)
        }
    }

    public func waitUntilExists(_ query: AccessibilityQuery, timeout: TimeInterval? = nil) throws {
        try self.runSynchronously { try await self.waitUntilExists(query, timeout: timeout) }
    }

    public func waitUntilVisible(_ query: AccessibilityQuery, visibility: Visibility = .partial,
                                 timeout: TimeInterval? = nil) throws
    {
        try self.runSynchronously {
            try await self.waitUntilVisible(query, visibility: visibility, timeout: timeout)
        }
    }

    public func waitUntilVisible(_ view: UIView, visibility: Visibility = .partial,
                                 timeout: TimeInterval? = nil) throws
    {
        try self.runSynchronously {
            try await self.waitUntilVisible(view, visibility: visibility, timeout: timeout)
        }
    }

    public func waitUntilVisible(_ rect: CGRect, visibility: Visibility = .partial,
                                 timeout: TimeInterval? = nil) throws
    {
        try self.runSynchronously {
            try await self.waitUntilVisible(rect, visibility: visibility, timeout: timeout)
        }
    }

    public func waitUntilVisible(_ point: CGPoint, timeout: TimeInterval? = nil) throws {
        try self.runSynchronously { try await self.waitUntilVisible(point, timeout: timeout) }
    }

    public func waitUntilHittable(_ accessibilityIdentifier: String, timeout: TimeInterval? = nil) throws {
        try self.runSynchronously {
            try await self.waitUntilHittable(accessibilityIdentifier, timeout: timeout)
        }
    }

    public func waitUntilHittable(_ query: AccessibilityQuery, timeout: TimeInterval? = nil) throws {
        try self.runSynchronously { try await self.waitUntilHittable(query, timeout: timeout) }
    }

    public func waitUntilHittable(_ view: UIView, timeout: TimeInterval? = nil) throws {
        try self.runSynchronously { try await self.waitUntilHittable(view, timeout: timeout) }
    }

    public func waitUntilHittable(_ point: CGPoint, timeout: TimeInterval? = nil) throws {
        try self.runSynchronously { try await self.waitUntilHittable(point, timeout: timeout) }
    }

    public func waitUntilHittable(timeout: TimeInterval? = nil) throws {
        try self.runSynchronously { try await self.waitUntilHittable(timeout: timeout) }
    }

    public func waitUntilRunloopIsFlushed(timeout: TimeInterval? = nil) throws {
        try self.runSynchronously { try await self.waitUntilRunloopIsFlushed(timeout: timeout) }
    }

    public func waitUntilFrameIsRendered(timeout: TimeInterval? = nil) throws {
        try self.runSynchronously { try await self.waitUntilFrameIsRendered(timeout: timeout) }
    }
}
