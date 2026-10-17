@testable import Hammer
import UIKit
import XCTest

@MainActor
final class LifecycleTests: XCTestCase {
    private var originalSettings = EventGenerator.Settings()

    override func setUp() async throws {
        try await super.setUp()
        self.originalSettings = EventGenerator.settings
        EventGenerator.settings.windowReadyTimeout = 0.3
    }

    override func tearDown() async throws {
        EventGenerator.settings = self.originalSettings
        try await super.tearDown()
    }

    func testNotReadyErrorIncludesReason() async throws {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UIViewController()

        do {
            _ = try await EventGenerator(window: window)
            XCTFail("The window should not be ready")
        } catch {
            guard case HammerError.windowIsNotReadyForInteraction(let reason) = error else {
                return XCTFail("Unexpected error: \(error)")
            }

            XCTAssertEqual(reason, .windowIsHidden)
            XCTAssertTrue("\(error)".contains("the window is hidden"))
        }
    }

    func testNotReadyErrorIsReportedAfterScrollViewTeardown() async throws {
        // Tearing down a scroll view makes UIKit throw and catch its own errors, which XCTest must not
        // report instead of the error that failed the test.
        let options = XCTExpectedFailure.Options()
        options.issueMatcher = { issue in
            issue.compactDescription.contains("not ready for interaction")
        }

        XCTExpectFailure("The window is not ready", options: options)

        let scrollView = PatternScrollView().withSize(width: 300, height: 300)
        let eventGenerator = try await EventGenerator(view: scrollView)
        eventGenerator.window.isUserInteractionEnabled = false
        try await eventGenerator.fingerTap()
    }

    func testTeardownCancelsFingersStillDown() async throws {
        let view = CancellationTestView()
        view.setSize(width: 100, height: 100)

        var eventGenerator: EventGenerator? = try await EventGenerator(view: view)
        try await eventGenerator?.waitUntilHittable(timeout: 1)
        try await eventGenerator?.fingerDown()
        XCTAssertEqual(view.cancelledTouchCount, 0)

        // Releasing the event generator only enqueues the cancellation, the next one waits for it
        eventGenerator = nil
        _ = try await EventGenerator(view: UIView().withSize(width: 100, height: 100))
        XCTAssertEqual(view.cancelledTouchCount, 1)
    }

    func testTapIsDeliveredToWindowPresentedAbove() async throws {
        let eventGenerator = try await EventGenerator(view: UIButton().withSize(width: 300, height: 300))
        try await eventGenerator.waitUntilHittable(timeout: 1)

        let overlayView = TouchCountingView()
        let overlayWindow = UIWindow(frame: eventGenerator.window.frame)
        overlayWindow.windowScene = eventGenerator.window.windowScene
        overlayWindow.windowLevel = eventGenerator.window.windowLevel + 1
        overlayWindow.rootViewController = UIViewController()
        overlayWindow.rootViewController?.view = overlayView
        overlayWindow.isHidden = false
        defer { overlayWindow.isHidden = true }

        try await eventGenerator.fingerTap()
        XCTAssertEqual(overlayView.endedTouchCount, 1)
    }
}

private final class CancellationTestView: UIView {
    private(set) var cancelledTouchCount = 0

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        self.cancelledTouchCount += touches.count
    }
}

private final class TouchCountingView: UIView {
    private(set) var endedTouchCount = 0

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        self.endedTouchCount += touches.count
    }
}
