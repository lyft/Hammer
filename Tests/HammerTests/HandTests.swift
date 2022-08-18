import Hammer
import UIKit
import XCTest

// swiftlint:disable:next type_body_length
final class HandTests: XCTestCase {
    func testButtonTap() throws {
        let view = UIButton()
        view.setSize(width: 100, height: 100)
        view.backgroundColor = .green

        let expectation = XCTestExpectation(description: "Button Tapped")
        view.addHandler(forEvent: .primaryActionTriggered, action: expectation.fulfill)

        let eventGenerator = try EventGenerator(view: view)
        try eventGenerator.waitUntilHittable(timeout: 1)
        try eventGenerator.fingerTap()

        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 1), .completed)
    }

    func testButtonTapOnHidden() throws {
        let view = UIButton()
        view.setSize(width: 100, height: 100)
        view.backgroundColor = .green
        view.isHidden = true

        let eventGenerator = try EventGenerator(view: view)
        try eventGenerator.wait(0.5)

        do {
            try eventGenerator.fingerTap()
            XCTFail("Button should not be tappable")
        } catch HammerError.viewIsNotVisible {
            // Success
        } catch {
            throw error
        }
    }

    func testButtonTapOnMinimumAlpha() throws {
        let view = UIButton()
        view.setSize(width: 100, height: 100)
        view.backgroundColor = .green
        view.alpha = 0.0001

        let eventGenerator = try EventGenerator(view: view)
        try eventGenerator.wait(0.5)

        do {
            try eventGenerator.fingerTap()
            XCTFail("Button should not be tappable")
        } catch HammerError.viewIsNotVisible {
            // Success
        } catch {
            throw error
        }
    }

    func testButtonTapOnNonInteractive() throws {
        let view = UIButton()
        view.setSize(width: 100, height: 100)
        view.backgroundColor = .green
        view.isUserInteractionEnabled = false

        let eventGenerator = try EventGenerator(view: view)
        try eventGenerator.wait(0.5)

        do {
            try eventGenerator.fingerTap()
            XCTFail("Button should not be tappable")
        } catch HammerError.viewIsNotHittable {
            // Success
        } catch {
            throw error
        }
    }

    func testButtonTapInsideOfBounds() throws {
        let containerView = UIView()
        containerView.setSize(width: 100, height: 100)
        containerView.backgroundColor = .blue
        containerView.clipsToBounds = false

        let view = UIButton()
        view.setSize(width: 100, height: 100)
        containerView.addSubview(view)
        view.setOrigin(x: 0, y: 0)

        let expectation = XCTestExpectation(description: "Button Tapped")
        view.addHandler(forEvent: .primaryActionTriggered, action: expectation.fulfill)

        let eventGenerator = try EventGenerator(view: containerView)
        try eventGenerator.waitUntilHittable(view, timeout: 1)
        try eventGenerator.fingerTap(at: view)

        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 1), .completed)
    }

    func testButtonTapOutOfBounds() throws {
        let containerView = UIView()
        containerView.setSize(width: 100, height: 100)
        containerView.backgroundColor = .blue

        let view = UIButton()
        view.setSize(width: 100, height: 100)
        view.backgroundColor = .green
        containerView.addSubview(view)
        view.setOrigin(x: 0, y: 100)

        let eventGenerator = try EventGenerator(view: containerView)
        try eventGenerator.wait(0.5)

        do {
            try eventGenerator.fingerTap(at: view)
            XCTFail("Button should not be tappable")
        } catch HammerError.viewIsNotHittable {
            // Success
        } catch {
            throw error
        }
    }

    func testButtonTapOutOfBoundsClipped() throws {
        let containerView = UIView()
        containerView.setSize(width: 100, height: 100)
        containerView.backgroundColor = .blue
        containerView.clipsToBounds = true

        let view = UIButton()
        view.setSize(width: 100, height: 100)
        view.backgroundColor = .green
        containerView.addSubview(view)
        view.setOrigin(x: 0, y: 100)

        let eventGenerator = try EventGenerator(view: containerView)
        try eventGenerator.wait(0.5)

        do {
            try eventGenerator.fingerTap(at: view)
            XCTFail("Button should not be tappable")
        } catch HammerError.viewIsNotVisible {
            // Success
        } catch {
            throw error
        }
    }

    func testButtonTapOnNonInteractiveSuperview() throws {
        let view = UIButton()
        view.setSize(width: 100, height: 100)
        view.accessibilityIdentifier = "my_button"
        view.backgroundColor = .green

        let containerView = UIView()
        containerView.setSize(width: 100, height: 100)
        containerView.backgroundColor = .blue
        containerView.isUserInteractionEnabled = false
        containerView.addSubview(view)

        let eventGenerator = try EventGenerator(view: containerView)
        try eventGenerator.wait(0.5)

        do {
            try eventGenerator.fingerTap(at: "my_button")
            XCTFail("Button should not be tappable")
        } catch HammerError.viewIsNotHittable {
            // Success
        } catch {
            throw error
        }
    }

    func testButtonHighlight() throws {
        let view = UIButton()
        view.setSize(width: 100, height: 100)
        view.backgroundColor = .green

        let touchDownExpectation = XCTestExpectation(description: "Button Touch Down")
        view.addHandler(forEvent: .touchDown, action: touchDownExpectation.fulfill)

        let touchUpExpectation = XCTestExpectation(description: "Button Touch Up")
        view.addHandler(forEvent: .touchUpInside, action: touchUpExpectation.fulfill)

        let eventGenerator = try EventGenerator(view: view)
        try eventGenerator.waitUntilHittable(timeout: 1)

        XCTAssertFalse(view.isHighlighted)
        try eventGenerator.fingerDown()
        try eventGenerator.wait(0.3)
        XCTAssertTrue(view.isHighlighted)
        try eventGenerator.fingerUp()
        try eventGenerator.wait(0.2)
        XCTAssertFalse(view.isHighlighted)

        XCTAssertEqual(XCTWaiter.wait(for: [touchDownExpectation, touchUpExpectation], timeout: 1),
                       .completed)
    }

    func testViewTapGesture() throws {
        let view = UIView()
        view.setSize(width: 100, height: 100)
        view.backgroundColor = .green

        let expectation = XCTestExpectation(description: "Button Tapped")
        let recognizer = UITapGestureRecognizer()
        recognizer.addHandler(forState: .recognized, action: expectation.fulfill)
        view.addGestureRecognizer(recognizer)

        let eventGenerator = try EventGenerator(view: view)
        try eventGenerator.waitUntilHittable(timeout: 1)
        try eventGenerator.fingerTap()

        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 1), .completed)
    }

    func testViewDoubleTapGesture() throws {
        let view = UIView()
        view.setSize(width: 100, height: 100)
        view.backgroundColor = .green

        let expectation = XCTestExpectation(description: "Button Double Tapped")
        let recognizer = UITapGestureRecognizer()
        recognizer.numberOfTapsRequired = 2
        recognizer.addHandler(forState: .recognized, action: expectation.fulfill)
        view.addGestureRecognizer(recognizer)

        let eventGenerator = try EventGenerator(view: view)
        try eventGenerator.waitUntilHittable(timeout: 1)
        try eventGenerator.fingerDoubleTap()

        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 3), .completed)
    }

    func testViewTwoFingerTapGesture() throws {
        let view = UIView()
        view.setSize(width: 100, height: 100)
        view.backgroundColor = .green

        let expectation = XCTestExpectation(description: "Button Two Finger Tapped")
        let recognizer = UITapGestureRecognizer()
        recognizer.numberOfTouchesRequired = 2
        recognizer.addHandler(forState: .recognized, action: expectation.fulfill)
        view.addGestureRecognizer(recognizer)

        let eventGenerator = try EventGenerator(view: view)
        try eventGenerator.waitUntilHittable(timeout: 1)
        try eventGenerator.twoFingerTap()

        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 3), .completed)
    }

    func testViewLongPressGesture() throws {
        let view = UIView()
        view.setSize(width: 100, height: 100)
        view.backgroundColor = .green

        let expectation = XCTestExpectation(description: "Button Long Pressed")
        let recognizer = UILongPressGestureRecognizer()
        recognizer.addHandler(forState: .recognized, action: expectation.fulfill)
        view.addGestureRecognizer(recognizer)

        let eventGenerator = try EventGenerator(view: view)
        try eventGenerator.waitUntilHittable(timeout: 1)
        try eventGenerator.fingerLongPress()

        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 3), .completed)
    }

    func testViewRotationGesture() throws {
        let view = UIView()
        view.setSize(width: 300, height: 300)
        view.backgroundColor = .green

        let expectation = XCTestExpectation(description: "View Rotated")
        let recognizer = UIRotationGestureRecognizer()
        recognizer.addHandler(forState: .recognized, action: expectation.fulfill)
        view.addGestureRecognizer(recognizer)

        let eventGenerator = try EventGenerator(view: view)
        try eventGenerator.waitUntilHittable(timeout: 1)
        try eventGenerator.fingerRotate(angle: .pi, duration: 0.2)

        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 3), .completed)
    }

    func testSwitchToggle() throws {
        let view = UISwitch()
        let eventGenerator = try EventGenerator(view: view)
        try eventGenerator.waitUntilHittable(timeout: 1)

        let expectation = XCTestExpectation(description: "Button Value Changed")
        view.addHandler(forEvent: .valueChanged, action: expectation.fulfill)

        XCTAssertFalse(view.isOn)
        try eventGenerator.fingerTap()
        XCTAssertTrue(view.isOn)

        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 1), .completed)
    }

    func testSwitchToggleOnOff() throws {
        let view = UISwitch()
        let eventGenerator = try EventGenerator(view: view)
        try eventGenerator.waitUntilHittable(timeout: 1)

        XCTAssertFalse(view.isOn)
        try eventGenerator.fingerDown(at: view.frame.center.offset(x: -20, y: 0))
        try eventGenerator.fingerMove(to: view.frame.center.offset(x: 40, y: 0), duration: 0.5)
        try eventGenerator.fingerUp()
        XCTAssertTrue(view.isOn)
        try eventGenerator.fingerDown(at: view.frame.center.offset(x: 20, y: 0))
        try eventGenerator.fingerMove(to: view.frame.center.offset(x: -40, y: 0), duration: 0.5)
        try eventGenerator.fingerUp()
        XCTAssertFalse(view.isOn)
    }

    func testScrollViewDrag() throws {
        let view = PatternScrollView()
        view.setSize(width: 300, height: 300)

        let eventGenerator = try EventGenerator(view: view)
        try eventGenerator.waitUntilHittable(timeout: 1)

        XCTAssertEqual(view.contentOffset, CGPoint(x: 0, y: 0))
        try eventGenerator.fingerDrag(from: view.frame.center.offset(x: 40, y: 100),
                                      to: view.frame.center.offset(x: -40, y: -100),
                                      duration: 1)
        XCTAssertEqual(view.contentOffset, CGPoint(x: 75, y: 190), accuracy: 10)
    }

    func testScrollViewDragWithTranslation() throws {
        let view = PatternScrollView()
        view.setSize(width: 300, height: 300)

        let eventGenerator = try EventGenerator(view: view)
        try eventGenerator.waitUntilHittable(timeout: 1)

        XCTAssertEqual(view.contentOffset, CGPoint(x: 0, y: 0))
        try eventGenerator.fingerDown(at: view.frame.center.offset(x: 40, y: 100))
        try eventGenerator.fingerMove(translationX: -80, y: -200, duration: 1)
        XCTAssertEqual(view.contentOffset, CGPoint(x: 75, y: 190), accuracy: 10)
    }

    func testScrollViewPinch() throws {
        let view = PatternScrollView()
        view.setSize(width: 300, height: 300)

        let eventGenerator = try EventGenerator(view: view)
        try eventGenerator.waitUntilHittable(timeout: 1)

        try eventGenerator.wait(0.3)
        XCTAssertEqual(view.zoomScale, 1)
        try eventGenerator.fingerPinchOpen(duration: 1)
        try eventGenerator.wait(0.3)
        XCTAssertEqual(view.zoomScale, 6.9, accuracy: 1)
        try eventGenerator.fingerPinchClose(duration: 1)
        try eventGenerator.wait(0.3)
        XCTAssertEqual(view.zoomScale, 1, accuracy: 0.1)
    }

    func testOffsetLocation() throws {
        let view = UIStackView()
        view.axis = .horizontal

        var expectations = [XCTestExpectation]()

        for i in 1...3 {
            let button = UIButton()
            button.setTitle("\(i)", for: .normal)
            button.setSize(width: 100, height: 100)
            let expectation = XCTestExpectation(description: "Button Tapped")
            expectation.assertForOverFulfill = true
            button.addHandler(forEvent: .primaryActionTriggered, action: expectation.fulfill)
            expectations.append(expectation)
            view.addArrangedSubview(button)
        }

        let eventGenerator = try EventGenerator(view: view)
        try eventGenerator.waitUntilHittable(view.subviews[0], timeout: 1)
        try eventGenerator.fingerTap(at: OffsetLocation(x: -100, y: 0))
        try eventGenerator.fingerTap(at: OffsetLocation(x: 0, y: 0))
        try eventGenerator.fingerTap(at: OffsetLocation(x: 100, y: 0))

        XCTAssertEqual(XCTWaiter.wait(for: expectations, timeout: 1, enforceOrder: true), .completed)
    }

    func testRelativeLocation() throws {
        let view = UIStackView()
        view.axis = .horizontal

        var expectations = [XCTestExpectation]()

        for i in 1...3 {
            let button = UIButton()
            button.setTitle("\(i)", for: .normal)
            button.setSize(width: 100, height: 100)
            let expectation = XCTestExpectation(description: "Button Tapped")
            expectation.assertForOverFulfill = true
            button.addHandler(forEvent: .primaryActionTriggered, action: expectation.fulfill)
            expectations.append(expectation)
            view.addArrangedSubview(button)
        }

        let eventGenerator = try EventGenerator(view: view)
        try eventGenerator.waitUntilHittable(view.subviews[0], timeout: 1)
        try eventGenerator.fingerTap(at: RelativeLocation(x: 0.2, y: 0.5))
        try eventGenerator.fingerTap(at: RelativeLocation(x: 0.5, y: 0.5))
        try eventGenerator.fingerTap(at: RelativeLocation(x: 0.8, y: 0.5))

        XCTAssertEqual(XCTWaiter.wait(for: expectations, timeout: 1, enforceOrder: true), .completed)
    }
}
