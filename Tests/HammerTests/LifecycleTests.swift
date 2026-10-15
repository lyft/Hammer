@testable import Hammer
import UIKit
import XCTest

final class LifecycleTests: XCTestCase {
    private var originalSettings = EventGenerator.settings

    override func setUp() {
        super.setUp()
        self.originalSettings = EventGenerator.settings
        EventGenerator.settings.windowReadyTimeout = 0.3
    }

    override func tearDown() {
        EventGenerator.settings = self.originalSettings
        super.tearDown()
    }

    func testNotReadyErrorIncludesReason() throws {
        UIApplication.shared.beginIgnoringInteractionEvents()
        defer { UIApplication.shared.endIgnoringInteractionEvents() }

        let view = UIButton().withSize(width: 100, height: 100)
        XCTAssertThrowsError(try EventGenerator(view: view)) { error in
            guard case HammerError.windowIsNotReadyForInteraction(let reason) = error else {
                return XCTFail("Unexpected error: \(error)")
            }

            XCTAssertEqual(reason, .applicationIsIgnoringInteractionEvents)
            XCTAssertTrue("\(error)".contains("the application is ignoring interaction events"))
        }
    }

    func testNotReadyErrorIsReportedAfterScrollViewTeardown() throws {
        // Tearing down a scroll view makes UIKit throw and catch its own errors, which XCTest must not
        // report instead of the error that failed the test.
        let options = XCTExpectedFailure.Options()
        options.issueMatcher = { issue in
            issue.compactDescription.contains("not ready for interaction")
        }

        XCTExpectFailure("The window is not ready", options: options)

        UIApplication.shared.beginIgnoringInteractionEvents()
        defer { UIApplication.shared.endIgnoringInteractionEvents() }

        _ = try EventGenerator(view: PatternScrollView().withSize(width: 300, height: 300))
    }

    func testTeardownCancelsFingersStillDown() throws {
        let view = CancellationTestView()
        view.setSize(width: 100, height: 100)

        var eventGenerator: EventGenerator? = try EventGenerator(view: view)
        try eventGenerator?.waitUntilHittable(timeout: 1)
        try eventGenerator?.fingerDown()
        XCTAssertEqual(view.cancelledTouchCount, 0)

        eventGenerator = nil
        XCTAssertEqual(view.cancelledTouchCount, 1)
    }

    func testWaitUntilClosureThrowsOnTimeout() throws {
        let eventGenerator = try EventGenerator(view: UIButton().withSize(width: 100, height: 100))
        XCTAssertThrowsError(try eventGenerator.waitUntil({ _ in }, timeout: 0.1)) { error in
            guard case HammerError.waitConditionTimeout = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }
}

private final class CancellationTestView: UIView {
    private(set) var cancelledTouchCount = 0

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        self.cancelledTouchCount += touches.count
    }
}

extension UIView {
    fileprivate func withSize(width: CGFloat, height: CGFloat) -> Self {
        self.setSize(width: width, height: height)
        return self
    }
}
