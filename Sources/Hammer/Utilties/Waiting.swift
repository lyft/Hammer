import Foundation
import UIKit

extension EventGenerator {
    /// Waits for a specified time.
    ///
    /// - parameter interval: The time to wait.
    ///
    /// - throws: `CancellationError` if the task is cancelled while waiting.
    public func wait(_ interval: TimeInterval) async throws {
        try await Task.sleep(for: .seconds(max(interval, 0)))
    }

    /// Waits for a condition to become true within the specified time.
    ///
    /// - parameter condition:     The condition to check.
    /// - parameter timeout:       The maximum time to wait for the condition to become true.
    /// - parameter checkInterval: How often should the condition be checked.
    ///
    /// - throws: An error if the condition did not return true within the specified time.
    public func waitUntil(_ condition: @autoclosure () throws -> Bool,
                          timeout: TimeInterval, checkInterval: TimeInterval = 0.1) async throws
    {
        try await self.waitUntilExists(try condition() ? true : nil,
                                       timeout: timeout, checkInterval: checkInterval)
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
    public func waitUntilExists<T>(_ exists: @autoclosure () throws -> T?,
                                   timeout: TimeInterval, checkInterval: TimeInterval = 0.1) async throws -> T
    {
        let deadline = ContinuousClock.now + .seconds(timeout)
        while true {
            if let element = try exists() {
                return element
            }

            let now = ContinuousClock.now
            if now >= deadline {
                throw HammerError.waitConditionTimeout(timeout)
            }

            try await Task.sleep(until: min(now + .seconds(checkInterval), deadline))
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
                                timeout: TimeInterval, checkInterval: TimeInterval = 0.1) async throws
    {
        try await self.waitUntilExists(try? self.viewWithIdentifier(accessibilityIdentifier),
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
                                 timeout: TimeInterval, checkInterval: TimeInterval = 0.1) async throws
    {
        try await self.waitUntil(self.viewIsVisible(accessibilityIdentifier, visibility: visibility),
                                 timeout: timeout, checkInterval: checkInterval)
    }

    /// Waits for a view to be visible within the specified time.
    ///
    /// - parameter view:          The view to wait for.
    /// - parameter visibility:    How determine if the view is visible.
    /// - parameter timeout:       The maximum time to wait for the view to be visible.
    /// - parameter checkInterval: How often should the view be checked.
    ///
    /// - throws: An error if the view is not visible after the specified time.
    public func waitUntilVisible(_ view: UIView, visibility: Visibility = .partial,
                                 timeout: TimeInterval, checkInterval: TimeInterval = 0.1) async throws
    {
        try await self.waitUntil(self.viewIsVisible(view, visibility: visibility),
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
                                 timeout: TimeInterval, checkInterval: TimeInterval = 0.1) async throws
    {
        try await self.waitUntil(self.rectIsVisible(rect, visibility: visibility),
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
                                 timeout: TimeInterval, checkInterval: TimeInterval = 0.1) async throws
    {
        try await self.waitUntil(self.pointIsVisible(point), timeout: timeout, checkInterval: checkInterval)
    }

    /// Waits for a view with the specified identifier to be hittable within the specified time.
    ///
    /// - parameter accessibilityIdentifier: The identifier of the view to wait for.
    /// - parameter timeout:                 The maximum time to wait for the view to be hittable.
    /// - parameter checkInterval:           How often should the view be checked.
    ///
    /// - throws: An error if the view is not hittable after the specified time.
    public func waitUntilHittable(_ accessibilityIdentifier: String,
                                  timeout: TimeInterval, checkInterval: TimeInterval = 0.1) async throws
    {
        try await self.waitUntil(self.viewIsHittable(accessibilityIdentifier),
                                 timeout: timeout, checkInterval: checkInterval)
    }

    /// Waits for a view to be hittable within the specified time.
    ///
    /// - parameter view:          The view to wait for.
    /// - parameter timeout:       The maximum time to wait for the view to be hittable.
    /// - parameter checkInterval: How often should the view be checked.
    ///
    /// - throws: An error if the view is not hittable after the specified time.
    public func waitUntilHittable(_ view: UIView,
                                  timeout: TimeInterval, checkInterval: TimeInterval = 0.1) async throws
    {
        try await self.waitUntil(self.viewIsHittable(view), timeout: timeout, checkInterval: checkInterval)
    }

    /// Waits for a point to be visible and hittable on screen within the specified time.
    ///
    /// - parameter point:         The point to wait for.
    /// - parameter timeout:       The maximum time to wait for the point to be hittable.
    /// - parameter checkInterval: How often should the view be checked.
    ///
    /// - throws: An error if the point is not hittable within the specified time.
    public func waitUntilHittable(_ point: CGPoint,
                                  timeout: TimeInterval, checkInterval: TimeInterval = 0.1) async throws
    {
        try await self.waitUntil(self.pointIsHittable(point), timeout: timeout, checkInterval: checkInterval)
    }

    /// Waits for the default touch location to be visible and hittable on screen within the specified time.
    ///
    /// - parameter timeout:       The maximum time to wait for the point to be hittable.
    /// - parameter checkInterval: How often should the view be checked.
    ///
    /// - throws: An error if the point is not hittable within the specified time.
    public func waitUntilHittable(timeout: TimeInterval, checkInterval: TimeInterval = 0.1) async throws {
        try await self.waitUntil(self.viewIsHittable(self.mainView),
                                 timeout: timeout, checkInterval: checkInterval)
    }

    /// Runs one step per frame over the duration, with the progress of each step from 0 to 1.
    ///
    /// Steps are never skipped when the main thread falls behind, so gesture recognizers see the whole path.
    ///
    /// - parameter duration: The time to spread the steps over.
    /// - parameter step:     The closure to run for each step, the last one with a progress of 1.
    ///
    /// - throws: An error if a step throws.
    func performSteps(duration: TimeInterval, step: (TimeInterval) async throws -> Void) async throws {
        let stepCount = max(Int((duration / EventGenerator.fingerMoveInterval).rounded(.up)), 1)
        let start = ContinuousClock.now
        for index in 1...stepCount {
            let progress = TimeInterval(index) / TimeInterval(stepCount)
            let stepTime = start + .seconds(duration * progress)
            if stepTime > .now {
                try await Task.sleep(until: stepTime)
            }

            try await step(progress)
        }
    }

    // MARK: - System waiting

    /// Waits for the main runloop is flushed and all scheduled tasks have executed.
    ///
    /// - parameter timeout: The maximum time to wait.
    ///
    /// - throws: An error if the runloop is not flushed within the specified time.
    public func waitUntilRunloopIsFlushed(timeout: TimeInterval) async throws {
        try await self.waitForCompletion(timeout: timeout) { complete in
            DispatchQueue.main.async {
                MainActor.assumeIsolated(complete)
            }
        }
    }

    /// Waits until a frame has completed rendering.
    ///
    /// - parameter timeout: The maximum time to wait for the frame to render.
    ///
    /// - throws: An error if no frame rendered within the specified time.
    public func waitUntilFrameIsRendered(timeout: TimeInterval) async throws {
        try await self.waitForCompletion(timeout: timeout) { complete in
            FrameTracker.shared.addNextFrameListener(complete)
        }
    }

    /// Calls the closure once the main run loop finishes its current pass, after UIKit's own work at the end
    /// of the pass, such as updating gesture recognizers.
    ///
    /// - parameter body: The closure to call.
    func afterRunLoopPass(_ body: @escaping @MainActor () -> Void) {
        let activities = CFRunLoopActivity([.beforeWaiting, .exit]).rawValue
        let observer = CFRunLoopObserverCreateWithHandler(nil, activities, false, CFIndex.max) { _, _ in
            MainActor.assumeIsolated(body)
        }

        CFRunLoopAddObserver(CFRunLoopGetMain(), observer, .commonModes)
    }

    /// Waits until the closure passed to `start` is called.
    ///
    /// - parameter timeout: The maximum time to wait for the completion.
    /// - parameter start:   Starts the work, receiving the closure to call once it completes.
    ///
    /// - throws: `HammerError.waitConditionTimeout` if the completion was not called in time,
    ///           `CancellationError` if the task was cancelled, or the error `start` throws.
    func waitForCompletion(timeout: TimeInterval,
                           start: (_ complete: @escaping @MainActor () -> Void) throws -> Void) async throws
    {
        try Task.checkCancellation()

        let completion = Completion()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                completion.continuation = continuation
                do {
                    try start { completion.resume(with: .success(())) }
                } catch {
                    completion.resume(with: .failure(error))
                    return
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
                    MainActor.assumeIsolated {
                        completion.resume(with: .failure(HammerError.waitConditionTimeout(timeout)))
                    }
                }
            }
        } onCancel: {
            Task { @MainActor in
                completion.resume(with: .failure(CancellationError()))
            }
        }
    }
}

/// Resumes a continuation only the first time, since a completion can arrive after its timeout.
@MainActor
private final class Completion {
    var continuation: CheckedContinuation<Void, Error>?

    func resume(with result: Result<Void, Error>) {
        self.continuation?.resume(with: result)
        self.continuation = nil
    }
}

extension Duration {
    var timeInterval: TimeInterval {
        TimeInterval(self.components.seconds) + TimeInterval(self.components.attoseconds) * 1e-18
    }
}
