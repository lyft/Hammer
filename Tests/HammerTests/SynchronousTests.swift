import Hammer
import UIKit
import XCTest

/// Covers the synchronous API that tests which are not async use.
@MainActor
final class SynchronousTests: XCTestCase {
    func testButtonTap() throws {
        let expectation = XCTestExpectation(description: "Button Tapped")

        let view = UIButton(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        view.accessibilityIdentifier = "my_button"
        view.addHandler(forEvent: .primaryActionTriggered, action: expectation.fulfill)

        let eventGenerator = try EventGenerator(view: view)
        try eventGenerator.waitUntilHittable("my_button", timeout: 1)
        try eventGenerator.fingerTap(at: "my_button")

        self.wait(for: [expectation], timeout: 1)
    }

    func testSwitchToggleWithMove() throws {
        let view = UISwitch()
        let eventGenerator = try EventGenerator(view: view)
        try eventGenerator.waitUntilHittable(timeout: 1)

        XCTAssertFalse(view.isOn)
        try eventGenerator.fingerDown(at: view.frame.center.offset(x: -20, y: 0))
        try eventGenerator.fingerMove(to: view.frame.center.offset(x: 20, y: 0), duration: 0.5)
        try eventGenerator.fingerUp()
        XCTAssertTrue(view.isOn)
    }

    func testStylusTap() throws {
        try XCTSkipUnless(UIDevice.current.supportsStylus, "Stylus tests only run on iPad")

        let expectation = XCTestExpectation(description: "Button Tapped")

        let view = UIButton(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        view.addHandler(forEvent: .primaryActionTriggered, action: expectation.fulfill)

        let eventGenerator = try EventGenerator(view: view)
        try eventGenerator.waitUntilHittable(timeout: 1)
        try eventGenerator.stylusTap()

        self.wait(for: [expectation], timeout: 1)
    }

    func testTypeOnTextField() throws {
        let view = UITextField()
        view.setSize(width: 300)
        view.disableTextSuggestions()
        view.autocapitalizationType = .none

        let eventGenerator = try EventGenerator(view: view)
        try eventGenerator.waitUntilHittable(timeout: 1)

        try eventGenerator.fingerTap()
        XCTAssertTrue(view.isFirstResponder)
        try eventGenerator.keyType("abcd")
        try eventGenerator.keyPress(.deleteOrBackspace)
        XCTAssertEqual(view.text, "abc")
    }

    func testWaitUntilCondition() throws {
        let eventGenerator = try EventGenerator(view: UIView().withSize(width: 100, height: 100))

        var isDone = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isDone = true
        }

        try eventGenerator.waitUntil(isDone, timeout: 1)
        XCTAssertTrue(isDone)
    }

    func testWaitUntilWaiterCompletes() throws {
        let eventGenerator = try EventGenerator(view: UIView().withSize(width: 100, height: 100))

        try eventGenerator.waitUntil({ waiter in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                do {
                    try waiter.complete()
                } catch {
                    XCTFail("Unexpected error: \(error)")
                }
            }
        }, timeout: 1)
    }

    func testWaitUntilWaiterThrowsOnTimeout() throws {
        let eventGenerator = try EventGenerator(view: UIView().withSize(width: 100, height: 100))
        XCTAssertThrowsError(try eventGenerator.waitUntil({ _ in }, timeout: 0.1)) { error in
            guard case HammerError.waitConditionTimeout = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testViewWithIdentifierWaitsForView() throws {
        let view = UIView().withSize(width: 100, height: 100)
        let eventGenerator = try EventGenerator(view: view)

        let lateView = UIView()
        lateView.accessibilityIdentifier = "late_view"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            view.addSubview(lateView)
        }

        XCTAssertEqual(try eventGenerator.viewWithIdentifier("late_view", timeout: 1), lateView)
    }

    func testErrorIsThrown() throws {
        let eventGenerator = try EventGenerator(view: UIView().withSize(width: 100, height: 100))
        XCTAssertThrowsError(try eventGenerator.fingerTap(at: "missing_view")) { error in
            guard case HammerError.unableToFindView("missing_view") = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }
}
