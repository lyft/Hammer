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

    /// Waits for a condition to become true within the specified time, checking it every frame.
    ///
    /// - parameter condition: The condition to check.
    /// - parameter timeout:   The maximum time to wait, or nil to use `settings.waitTimeout`.
    ///
    /// - throws: An error if the condition did not return true within the specified time.
    public func waitUntil(_ condition: @autoclosure () throws -> Bool,
                          timeout: TimeInterval? = nil) async throws
    {
        try await self.waitUntilExists(try condition() ? true : nil, timeout: timeout)
    }

    /// Waits for a closure to return non-nil within the specified time, checking it every frame.
    ///
    /// - parameter exists:  The closure to check.
    /// - parameter timeout: The maximum time to wait, or nil to use `settings.waitTimeout`.
    ///
    /// - throws: An error if the closure did not return an object within the specified time.
    ///
    /// - returns: The non-nil object.
    @discardableResult
    public func waitUntilExists<T>(_ exists: @autoclosure () throws -> T?,
                                   timeout: TimeInterval? = nil) async throws -> T
    {
        let timeout = timeout ?? self.settings.waitTimeout
        let deadline = Deadline(timeout: timeout)
        while true {
            if let element = try exists() {
                return element
            }

            if deadline.hasPassed {
                throw HammerError.waitConditionTimeout(timeout)
            }

            try await self.waitForNextFrame(before: deadline)
        }
    }

    /// Waits for a view or SwiftUI element with the specified identifier to exist within the specified time.
    ///
    /// - parameter accessibilityIdentifier: The identifier of the view to wait for.
    /// - parameter timeout:                 The maximum time to wait, or nil to use `settings.waitTimeout`.
    ///
    /// - throws: An error if the view does not exist after the specified time.
    public func waitUntilExists(_ accessibilityIdentifier: String,
                                timeout: TimeInterval? = nil) async throws
    {
        try await self.waitUntilExists(.identifier(accessibilityIdentifier), timeout: timeout)
    }

    /// Waits for a view or accessibility element that matches the query to exist within the specified time.
    ///
    /// - parameter query:   The query of the element to wait for.
    /// - parameter timeout: The maximum time to wait, or nil to use `settings.waitTimeout`.
    ///
    /// - throws: An error if the element does not exist after the specified time.
    public func waitUntilExists(_ query: AccessibilityQuery, timeout: TimeInterval? = nil) async throws {
        try await self.waitUntil(self.elementExists(query), timeout: timeout)
    }

    /// Waits for a view or SwiftUI element with the specified identifier to be visible within the specified
    /// time.
    ///
    /// - parameter accessibilityIdentifier: The identifier of the view to wait for.
    /// - parameter visibility:              How determine if the view is visible.
    /// - parameter timeout:                 The maximum time to wait, or nil to use `settings.waitTimeout`.
    ///
    /// - throws: An error if the view does not exist after the specified time.
    public func waitUntilVisible(_ accessibilityIdentifier: String, visibility: Visibility = .partial,
                                 timeout: TimeInterval? = nil) async throws
    {
        try await self.waitUntilVisible(.identifier(accessibilityIdentifier), visibility: visibility,
                                        timeout: timeout)
    }

    /// Waits for a view or accessibility element that matches the query to be visible within the specified
    /// time.
    ///
    /// - parameter query:      The query of the element to wait for.
    /// - parameter visibility: How determine if the element is visible.
    /// - parameter timeout:    The maximum time to wait, or nil to use `settings.waitTimeout`.
    ///
    /// - throws: An error if the element is not visible after the specified time, or if multiple elements
    ///           match and `throwOnMultipleMatches` is set.
    public func waitUntilVisible(_ query: AccessibilityQuery, visibility: Visibility = .partial,
                                 timeout: TimeInterval? = nil) async throws
    {
        try await self.waitUntil(try self.accessibilityElement(matching: query)
                                    .map { self.isVisible($0, visibility: visibility) } ?? false,
                                 timeout: timeout)
    }

    /// Waits for a view to be visible within the specified time.
    ///
    /// - parameter view:       The view to wait for.
    /// - parameter visibility: How determine if the view is visible.
    /// - parameter timeout:    The maximum time to wait, or nil to use `settings.waitTimeout`.
    ///
    /// - throws: An error if the view is not visible after the specified time.
    public func waitUntilVisible(_ view: UIView, visibility: Visibility = .partial,
                                 timeout: TimeInterval? = nil) async throws
    {
        try await self.waitUntil(self.viewIsVisible(view, visibility: visibility), timeout: timeout)
    }

    /// Waits for a rect to be visible on screen within the specified time.
    ///
    /// - parameter rect:       The rect to wait for.
    /// - parameter visibility: How determine if the view is visible.
    /// - parameter timeout:    The maximum time to wait, or nil to use `settings.waitTimeout`.
    ///
    /// - throws: An error if the rect is not visible within the specified time.
    public func waitUntilVisible(_ rect: CGRect, visibility: Visibility = .partial,
                                 timeout: TimeInterval? = nil) async throws
    {
        try await self.waitUntil(self.rectIsVisible(rect, visibility: visibility), timeout: timeout)
    }

    /// Waits for a point to be visible on screen within the specified time.
    ///
    /// - parameter point:   The point to wait for.
    /// - parameter timeout: The maximum time to wait, or nil to use `settings.waitTimeout`.
    ///
    /// - throws: An error if the point is not visible within the specified time.
    public func waitUntilVisible(_ point: CGPoint, timeout: TimeInterval? = nil) async throws {
        try await self.waitUntil(self.pointIsVisible(point), timeout: timeout)
    }

    /// Waits for a view or SwiftUI element with the specified identifier to be hittable within the specified
    /// time.
    ///
    /// - parameter accessibilityIdentifier: The identifier of the view to wait for.
    /// - parameter timeout:                 The maximum time to wait, or nil to use `settings.waitTimeout`.
    ///
    /// - throws: An error if the view is not hittable after the specified time.
    public func waitUntilHittable(_ accessibilityIdentifier: String,
                                  timeout: TimeInterval? = nil) async throws
    {
        try await self.waitUntilHittable(.identifier(accessibilityIdentifier), timeout: timeout)
    }

    /// Waits for a view or accessibility element that matches the query to be hittable within the specified
    /// time.
    ///
    /// - parameter query:   The query of the element to wait for.
    /// - parameter timeout: The maximum time to wait, or nil to use `settings.waitTimeout`.
    ///
    /// - throws: An error if the element is not hittable after the specified time, or if multiple elements
    ///           match and `throwOnMultipleMatches` is set.
    public func waitUntilHittable(_ query: AccessibilityQuery, timeout: TimeInterval? = nil) async throws {
        try await self.waitUntil(try self.accessibilityElement(matching: query).map(self.isHittable) ?? false,
                                 timeout: timeout)
    }

    /// Waits for a view to be hittable within the specified time.
    ///
    /// - parameter view:    The view to wait for.
    /// - parameter timeout: The maximum time to wait, or nil to use `settings.waitTimeout`.
    ///
    /// - throws: An error if the view is not hittable after the specified time.
    public func waitUntilHittable(_ view: UIView, timeout: TimeInterval? = nil) async throws {
        try await self.waitUntil(self.viewIsHittable(view), timeout: timeout)
    }

    /// Waits for a point to be visible and hittable on screen within the specified time.
    ///
    /// - parameter point:   The point to wait for.
    /// - parameter timeout: The maximum time to wait, or nil to use `settings.waitTimeout`.
    ///
    /// - throws: An error if the point is not hittable within the specified time.
    public func waitUntilHittable(_ point: CGPoint, timeout: TimeInterval? = nil) async throws {
        try await self.waitUntil(self.pointIsHittable(point), timeout: timeout)
    }

    /// Waits for the default touch location to be visible and hittable on screen within the specified time.
    ///
    /// - parameter timeout: The maximum time to wait, or nil to use `settings.waitTimeout`.
    ///
    /// - throws: An error if the point is not hittable within the specified time.
    public func waitUntilHittable(timeout: TimeInterval? = nil) async throws {
        try await self.waitUntil(self.viewIsHittable(self.mainView), timeout: timeout)
    }

    /// Runs the steps over the duration, each on its own frame, with the progress of each step from 0 to 1.
    ///
    /// Steps are never skipped or sent within the same frame when the main thread falls behind, so gesture
    /// recognizers see the whole path.
    ///
    /// - parameter duration: The time to spread the steps over.
    /// - parameter step:     The closure to run for each step, the last one with a progress of 1.
    ///
    /// - throws: An error if a step throws or no frame renders.
    func performSteps(duration: TimeInterval, step: (TimeInterval) async throws -> Void) async throws {
        let stepCount = max(Int((duration / EventGenerator.fingerMoveInterval).rounded(.up)), 1)
        let frames = FrameTracker.shared
        let start = CACurrentMediaTime()
        var lastStepFrame: Int?
        for index in 1...stepCount {
            let progress = TimeInterval(index) / TimeInterval(stepCount)
            let stepTime = start + duration * progress

            // UIKit handles events once per frame, so each step goes out on the first frame due at its time
            while frames.frameCount == lastStepFrame || frames.nextFrameTime < stepTime {
                try await self.waitUntilFrameIsRendered(timeout: self.settings.eventProcessingTimeout)
            }

            lastStepFrame = frames.frameCount
            try await step(progress)
        }
    }

    // MARK: - System waiting

    /// Waits until the main run loop finishes its current pass, so the work scheduled so far has run.
    ///
    /// - parameter timeout: The maximum time to wait, or nil to use `settings.waitTimeout`.
    ///
    /// - throws: An error if the runloop is not flushed within the specified time.
    public func waitUntilRunloopIsFlushed(timeout: TimeInterval? = nil) async throws {
        try await self.waitForCompletion(timeout: timeout ?? self.settings.waitTimeout) { complete in
            self.afterRunLoopPass(complete)
        }
    }

    /// Waits until a frame has completed rendering.
    ///
    /// - parameter timeout: The maximum time to wait, or nil to use `settings.waitTimeout`.
    ///
    /// - throws: An error if no frame rendered within the specified time.
    public func waitUntilFrameIsRendered(timeout: TimeInterval? = nil) async throws {
        try await self.waitForCompletion(timeout: timeout ?? self.settings.waitTimeout) { complete in
            FrameTracker.shared.addNextFrameListener(complete)
        }
    }

    /// Waits for the next frame, or until the deadline when no frame renders before it.
    ///
    /// - parameter deadline: The latest time to wait until.
    ///
    /// - throws: `CancellationError` if the task is cancelled while waiting.
    func waitForNextFrame(before deadline: Deadline) async throws {
        do {
            try await self.waitUntilFrameIsRendered(timeout: deadline.remaining)
        } catch HammerError.waitConditionTimeout {
            return
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
    /// - parameter timeout: The maximum app time to wait for the completion.
    /// - parameter start:   Starts the work, receiving the closure to call once it completes.
    ///
    /// - throws: `HammerError.waitConditionTimeout` if the completion was not called in time,
    ///           `CancellationError` if the task was cancelled, or the error `start` throws.
    func waitForCompletion(timeout: TimeInterval,
                           start: (_ complete: @escaping @MainActor () -> Void) throws -> Void) async throws
    {
        try Task.checkCancellation()

        let completion = Completion()
        let deadline = Deadline(timeout: timeout)
        func scheduleTimeout() {
            DispatchQueue.main.asyncAfter(deadline: .now() + deadline.remaining) {
                MainActor.assumeIsolated {
                    // A stall while waiting moves the deadline later
                    guard deadline.hasPassed else {
                        return scheduleTimeout()
                    }

                    completion.resume(with: .failure(HammerError.waitConditionTimeout(timeout)))
                }
            }
        }

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                completion.continuation = continuation
                do {
                    try start { completion.resume(with: .success(())) }
                } catch {
                    completion.resume(with: .failure(error))
                    return
                }

                scheduleTimeout()
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
