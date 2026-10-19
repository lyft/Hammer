import Foundation

/// A point in app time, which does not advance while the main thread is stalled.
@MainActor
struct Deadline {
    private var time: TimeInterval

    /// The time left until the deadline, or 0 once it has passed.
    var remaining: TimeInterval {
        max(self.time - FrameTracker.shared.appTime, 0)
    }

    /// If the deadline has passed.
    var hasPassed: Bool {
        self.remaining == 0
    }

    /// Initialize a deadline for the specified time from now.
    ///
    /// - parameter timeout: The app time from now until the deadline.
    init(timeout: TimeInterval) {
        self.time = FrameTracker.shared.appTime + timeout
    }

    /// Moves the deadline later.
    ///
    /// - parameter interval: The time to move it by.
    mutating func extend(by interval: TimeInterval) {
        self.time += interval
    }
}
