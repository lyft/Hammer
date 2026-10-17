import CoreFoundation
import Foundation

/// Waits by running the main run loop, for code that cannot suspend.
@MainActor
enum MainRunLoop {
    /// Runs the main run loop until the condition is true.
    ///
    /// - parameter condition: The condition to check after each pass.
    /// - parameter timeout:   The maximum time to run, or nil to run until the condition is true.
    ///
    /// - returns: If the condition became true.
    @discardableResult
    static func run(until condition: () -> Bool, timeout: TimeInterval?) -> Bool {
        let deadline = timeout.map { ContinuousClock.now + .seconds($0) }
        while !condition() {
            if let deadline, ContinuousClock.now >= deadline {
                return false
            }

            // Short passes also notice conditions changed by run loop observers, which end no pass
            _ = CFRunLoopRunInMode(.defaultMode, 0.01, true)
        }

        return true
    }
}
