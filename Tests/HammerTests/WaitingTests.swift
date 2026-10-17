import CoreGraphics
import Hammer
import UIKit
import XCTest

@MainActor
final class WaitingTests: XCTestCase {
    func testWaitUntilVisibleWithIdentifier() async throws {
        let view = UIButton(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        view.accessibilityIdentifier = "my_button"
        view.setContentHuggingPriority(.required, for: .vertical)
        view.setContentHuggingPriority(.required, for: .horizontal)
        view.backgroundColor = .green

        let eventGenerator = try await EventGenerator(view: view)
        try await eventGenerator.waitUntilHittable(timeout: 1)

        view.isHidden = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            view.isHidden = false
        }

        XCTAssertFalse(eventGenerator.viewIsVisible("my_button"))
        try await eventGenerator.waitUntilVisible("my_button", timeout: 1)
        XCTAssertTrue(eventGenerator.viewIsVisible("my_button"))
    }

    func testWaitUntilVisible() async throws {
        let view = UIButton(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        view.accessibilityIdentifier = "my_button"
        view.setContentHuggingPriority(.required, for: .vertical)
        view.setContentHuggingPriority(.required, for: .horizontal)
        view.backgroundColor = .green

        let eventGenerator = try await EventGenerator(view: view)
        try await eventGenerator.waitUntilHittable(timeout: 1)

        view.isHidden = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            view.isHidden = false
        }

        XCTAssertFalse(eventGenerator.viewIsVisible(view))
        try await eventGenerator.waitUntilVisible(view, timeout: 1)
        XCTAssertTrue(eventGenerator.viewIsVisible(view))
    }

    func testWaitUntilVisibleMove() async throws {
        let view = UIButton()
        view.accessibilityIdentifier = "my_button"
        view.backgroundColor = .green

        let scrollView = PatternScrollView()
        scrollView.setSize(width: 300, height: 300)
        scrollView.addSubview(view, at: CGRect(x: 0, y: 400, width: 50, height: 50))

        let eventGenerator = try await EventGenerator(view: scrollView)
        try await eventGenerator.waitUntilHittable(timeout: 1)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            scrollView.scrollRectToVisible(view.frame, animated: false)
        }

        XCTAssertFalse(eventGenerator.viewIsVisible("my_button"))
        try await eventGenerator.waitUntilVisible("my_button", timeout: 1)
        XCTAssertTrue(eventGenerator.viewIsVisible("my_button"))
    }

    func testWaitUntilHittableWithIdentifier() async throws {
        let view = UIButton(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        view.accessibilityIdentifier = "my_button"
        view.setContentHuggingPriority(.required, for: .vertical)
        view.setContentHuggingPriority(.required, for: .horizontal)
        view.backgroundColor = .green

        let eventGenerator = try await EventGenerator(view: view)
        try await eventGenerator.waitUntilHittable(timeout: 1)

        view.isUserInteractionEnabled = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            view.isUserInteractionEnabled = true
        }

        XCTAssertFalse(eventGenerator.viewIsHittable("my_button"))
        try await eventGenerator.waitUntilHittable("my_button", timeout: 1)
        XCTAssertTrue(eventGenerator.viewIsHittable("my_button"))
    }

    func testViewForIdentifierWithTimeout() async throws {
        let view = UIButton(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        view.accessibilityIdentifier = "my_button"
        view.setContentHuggingPriority(.required, for: .vertical)
        view.setContentHuggingPriority(.required, for: .horizontal)
        view.backgroundColor = .green

        let eventGenerator = try await EventGenerator(view: view)
        try await eventGenerator.waitUntilHittable(timeout: 1)

        let button = try await eventGenerator.viewWithIdentifier("my_button", ofType: UIButton.self,
                                                                 timeout: 0.1)
        XCTAssertEqual(button, view)
    }

    func testViewForIdentifierWithInvalidIdentifier() async throws {
        let view = UIButton(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        view.accessibilityIdentifier = "my_button"
        view.setContentHuggingPriority(.required, for: .vertical)
        view.setContentHuggingPriority(.required, for: .horizontal)
        view.backgroundColor = .green

        let eventGenerator = try await EventGenerator(view: view)
        try await eventGenerator.waitUntilHittable(timeout: 1)

        let expectation = XCTestExpectation(description: "View is not found")

        do {
            _ = try eventGenerator.viewWithIdentifier("my_other_button", ofType: UIButton.self)
        } catch HammerError.unableToFindView(let identifier) {
            XCTAssertEqual(identifier, "my_other_button")
            expectation.fulfill()
        }

        await self.fulfillment(of: [expectation], timeout: 1)
    }
}
