import Darwin
import Dispatch

private let kHookNames: [String] = ["_swift_willThrow", "_swift_willThrowTypedImpl"]

/// The Swift runtime hooks called whenever a Swift error is thrown.
///
/// Swift Testing installs these to record thrown errors, and XCTest then describes a failed test with the
/// last error recorded. UIKit's gesture system throws and catches errors internally when views leave a
/// window, so a teardown while a Hammer error is propagating would replace the error that failed the test.
@MainActor
enum SwiftErrorHooks {
    private typealias Hook = UnsafeMutablePointer<UnsafeRawPointer?>

    private static let hooks: [Hook] = kHookNames.compactMap { name in
        dlsym(UnsafeMutableRawPointer(bitPattern: -2), name)?.assumingMemoryBound(to: UnsafeRawPointer?.self)
    }

    private static var installedHooks: [UnsafeRawPointer?] = []
    private static var suspensionCount = 0

    /// Runs the closure with the hooks disabled, and keeps them disabled until the main queue runs the work
    /// enqueued so far, so that objects released when the caller returns are covered too.
    ///
    /// - parameter body: The closure to run.
    static func suspend(during body: () -> Void) {
        if self.suspensionCount == 0 {
            self.installedHooks = self.hooks.map { $0.pointee }
            self.hooks.forEach { $0.pointee = nil }
        }

        self.suspensionCount += 1
        body()
        DispatchQueue.main.async {
            self.suspensionCount -= 1
            if self.suspensionCount == 0 {
                zip(self.hooks, self.installedHooks).forEach { hook, installedHook in
                    hook.pointee = installedHook
                }
            }
        }
    }
}
