import Darwin

private let kHookNames: [String] = ["_swift_willThrow", "_swift_willThrowTypedImpl"]

/// The Swift runtime hooks called whenever a Swift error is thrown.
///
/// Swift Testing installs these to record thrown errors, and XCTest then describes a failed test with the
/// last error recorded. UIKit's gesture system throws and catches errors internally when views leave a
/// window, so a teardown while a Hammer error is propagating would replace the error that failed the test.
enum SwiftErrorHooks {
    private typealias Hook = UnsafeMutablePointer<UnsafeRawPointer?>

    nonisolated(unsafe) private static let hooks: [Hook] = kHookNames.compactMap { name in
        dlsym(UnsafeMutableRawPointer(bitPattern: -2), name)?.assumingMemoryBound(to: UnsafeRawPointer?.self)
    }

    /// Runs the closure with the hooks disabled.
    ///
    /// - parameter body: The closure to run.
    static func suspend(during body: () -> Void) {
        let installedHooks = self.hooks.map { $0.pointee }
        self.hooks.forEach { $0.pointee = nil }
        defer {
            zip(self.hooks, installedHooks).forEach { hook, installedHook in hook.pointee = installedHook }
        }

        body()
    }
}
