import CoreGraphics
import Hammer
import UIKit
import XCTest

final class WaitingTests: XCTestCase {
    func testWaitUntilVisibleWithIdentifier() throws {
        let view = UIButton(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        view.accessibilityIdentifier = "my_button"
        view.setContentHuggingPriority(.required, for: .vertical)
        view.setContentHuggingPriority(.required, for: .horizontal)
        view.backgroundColor = .green

        let eventGenerator = try EventGenerator(view: view)
        try eventGenerator.waitUntilHittable(timeout: 1)

        view.isHidden = true
        let timer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: false) { _ in
            view.isHidden = false
        }

        XCTAssertFalse(eventGenerator.viewIsVisible("my_button"))
        try eventGenerator.waitUntilVisible("my_button", timeout: 1)
        XCTAssertTrue(eventGenerator.viewIsVisible("my_button"))
        timer.invalidate()
    }

    func testWaitUntilVisible() throws {
        let view = UIButton(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        view.accessibilityIdentifier = "my_button"
        view.setContentHuggingPriority(.required, for: .vertical)
        view.setContentHuggingPriority(.required, for: .horizontal)
        view.backgroundColor = .green

        let eventGenerator = try EventGenerator(view: view)
        try eventGenerator.waitUntilHittable(timeout: 1)

        view.isHidden = true
        let timer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: false) { _ in
            view.isHidden = false
        }

        XCTAssertFalse(eventGenerator.viewIsVisible(view))
        try eventGenerator.waitUntilVisible(view, timeout: 1)
        XCTAssertTrue(eventGenerator.viewIsVisible(view))
        timer.invalidate()
    }

    func testWaitUntilVisibleMove() throws {
        let view = UIButton()
        view.accessibilityIdentifier = "my_button"
        view.backgroundColor = .green

        let scrollView = PatternScrollView()
        scrollView.widthAnchor.constraint(equalToConstant: 300).isActive = true
        scrollView.heightAnchor.constraint(equalToConstant: 300).isActive = true
        scrollView.addSubview(view, at: CGRect(x: 0, y: 400, width: 50, height: 50))

        let eventGenerator = try EventGenerator(view: scrollView)
        try eventGenerator.waitUntilHittable(timeout: 1)

        let timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { _ in
            scrollView.scrollRectToVisible(view.frame, animated: false)
        }

        XCTAssertFalse(eventGenerator.viewIsVisible("my_button"))
        try eventGenerator.waitUntilVisible("my_button", timeout: 1)
        XCTAssertTrue(eventGenerator.viewIsVisible("my_button"))
        timer.invalidate()
    }

    func testWaitUntilHittableWithIdentifier() throws {
        let view = UIButton(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        view.accessibilityIdentifier = "my_button"
        view.setContentHuggingPriority(.required, for: .vertical)
        view.setContentHuggingPriority(.required, for: .horizontal)
        view.backgroundColor = .green

        let eventGenerator = try EventGenerator(view: view)
        try eventGenerator.waitUntilHittable(timeout: 1)

        view.isUserInteractionEnabled = false
        let timer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: false) { _ in
            view.isUserInteractionEnabled = true
        }

        XCTAssertFalse(eventGenerator.viewIsHittable("my_button"))
        try eventGenerator.waitUntilHittable("my_button", timeout: 1)
        XCTAssertTrue(eventGenerator.viewIsHittable("my_button"))
        timer.invalidate()
    }

    func testViewForIdentifierWithTimeout() throws {
        let view = UIButton(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        view.accessibilityIdentifier = "my_button"
        view.setContentHuggingPriority(.required, for: .vertical)
        view.setContentHuggingPriority(.required, for: .horizontal)
        view.backgroundColor = .green

        let eventGenerator = try EventGenerator(view: view)
        try eventGenerator.waitUntilHittable(timeout: 1)

        let button = try eventGenerator.viewWithIdentifier("my_button", ofType: UIButton.self, timeout: 0.1)
        XCTAssertEqual(button, view)
    }
}
