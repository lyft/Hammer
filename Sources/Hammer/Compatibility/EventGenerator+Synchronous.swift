import SwiftUI
import UIKit

// Synchronous versions of the async API, for tests that are not async. Swift picks these in synchronous
// code and the async versions in async code.
extension EventGenerator {
    public convenience init(window: UIWindow) throws {
        self.init(window: window, mainView: window)
        try self.runSynchronously { try await self.waitUntilWindowIsReady() }
    }

    public convenience init(viewController: UIViewController) throws {
        let (window, presentedWindow) = EventGenerator.window(for: viewController)
        self.init(window: window, mainView: viewController.view, presentedWindow: presentedWindow)
        try self.runSynchronously { try await self.waitUntilWindowIsReady() }
    }

    public convenience init(view: UIView, alignment: WrappingAlignment = .center) throws {
        let (window, presentedWindow) = EventGenerator.window(for: view, alignment: alignment)
        self.init(window: window, mainView: view, presentedWindow: presentedWindow)
        try self.runSynchronously { try await self.waitUntilWindowIsReady() }
    }

    public convenience init(view: some View, alignment: WrappingAlignment = .center) throws {
        let hostingController = EventGenerator.hostingController(for: view)
        let window = EventGenerator.window(for: hostingController, alignment: alignment)
        self.init(window: window, mainView: hostingController.view, presentedWindow: window)
        try self.runSynchronously { try await self.waitUntilWindowIsReady() }
    }

    public func finish() throws {
        try self.runSynchronously { try await self.finish() }
    }

    public func waitUntilWindowIsReady(timeout: TimeInterval? = nil) throws {
        try self.runSynchronously { try await self.waitUntilWindowIsReady(timeout: timeout) }
    }

    public func waitUntilAnimationsAreFinished(timeout: TimeInterval? = nil) throws {
        try self.runSynchronously { try await self.waitUntilAnimationsAreFinished(timeout: timeout) }
    }

    public func viewWithIdentifier(_ accessibilityIdentifier: String,
                                   timeout: TimeInterval) throws -> UIView
    {
        try self.runSynchronously {
            try await self.viewWithIdentifier(accessibilityIdentifier, timeout: timeout)
        }
    }

    public func viewWithIdentifier<T: UIView>(_ accessibilityIdentifier: String, ofType type: T.Type,
                                              timeout: TimeInterval) throws -> T
    {
        try self.runSynchronously {
            try await self.viewWithIdentifier(accessibilityIdentifier, ofType: type, timeout: timeout)
        }
    }

    /// Runs async work to completion from synchronous code.
    ///
    /// The main run loop keeps running while waiting, so UIKit and the work itself can make progress on the
    /// main thread.
    ///
    /// - parameter operation: The work to run.
    ///
    /// - throws: The error the work throws.
    ///
    /// - returns: The value the work returns.
    func runSynchronously<T>(_ operation: @escaping @MainActor () async throws -> T) throws -> T {
        var result: Result<T, Error>?
        Task { @MainActor in
            do {
                result = .success(try await operation())
            } catch {
                result = .failure(error)
            }
        }

        // The work has its own timeouts
        MainRunLoop.run(until: { result != nil }, timeout: nil)
        guard let result else {
            preconditionFailure("The main run loop stopped before the work completed")
        }

        return try result.get()
    }
}
