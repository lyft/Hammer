import UIKit
import XCTest

// Synchronous versions of the async API, for tests that are not async. Swift picks these in synchronous
// code and the async versions in async code.
extension EventGenerator {
    public convenience init(window: UIWindow) throws {
        self.init(window: window, mainView: window)
        try self.runSynchronously { try await self.waitUntilWindowIsReady() }
    }

    public convenience init(viewController: UIViewController) throws {
        self.init(window: EventGenerator.window(for: viewController), mainView: viewController.view)
        try self.runSynchronously { try await self.waitUntilWindowIsReady() }
    }

    public convenience init(view: UIView, alignment: WrappingAlignment = .center) throws {
        self.init(window: EventGenerator.window(for: view, alignment: alignment), mainView: view)
        try self.runSynchronously { try await self.waitUntilWindowIsReady() }
    }

    public func waitUntilWindowIsReady(timeout: TimeInterval = EventGenerator.settings.windowReadyTimeout)
        throws
    {
        try self.runSynchronously { try await self.waitUntilWindowIsReady(timeout: timeout) }
    }

    public func waitUntilAnimationsAreFinished(timeout: TimeInterval) throws {
        try self.runSynchronously { try await self.waitUntilAnimationsAreFinished(timeout: timeout) }
    }

    public func viewWithIdentifier(_ accessibilityIdentifier: String, timeout: TimeInterval,
                                   checkInterval: TimeInterval = 0.1) throws -> UIView
    {
        try self.runSynchronously {
            try await self.viewWithIdentifier(accessibilityIdentifier, timeout: timeout,
                                              checkInterval: checkInterval)
        }
    }

    public func viewWithIdentifier<T: UIView>(_ accessibilityIdentifier: String, ofType type: T.Type,
                                              timeout: TimeInterval,
                                              checkInterval: TimeInterval = 0.1) throws -> T
    {
        try self.runSynchronously {
            try await self.viewWithIdentifier(accessibilityIdentifier, ofType: type, timeout: timeout,
                                              checkInterval: checkInterval)
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
        let outcome = Outcome<T>()
        let expectation = XCTestExpectation(description: "Hammer-Synchronous")
        Task { @MainActor in
            do {
                outcome.result = .success(try await operation())
            } catch {
                outcome.result = .failure(error)
            }

            expectation.fulfill()
        }

        while true {
            if let result = outcome.result {
                return try result.get()
            }

            // The timeouts that matter are inside the work, this only bounds each run loop pass
            _ = XCTWaiter.wait(for: [expectation], timeout: 1)
        }
    }
}

@MainActor
private final class Outcome<T> {
    var result: Result<T, Error>?
}
