import Hammer
import UIKit
import XCTest

@MainActor
// swiftlint:disable:next type_body_length
final class HandTests: XCTestCase {
    func testButtonTap() async throws {
        let view = UIButton()
        view.setSize(width: 100, height: 100)
        view.backgroundColor = .green

        let expectation = XCTestExpectation(description: "Button Tapped")
        view.addHandler(forEvent: .primaryActionTriggered, action: expectation.fulfill)

        let eventGenerator = try await EventGenerator(view: view)
        try await eventGenerator.waitUntilHittable(timeout: 1)
        try await eventGenerator.fingerTap()

        await self.fulfillment(of: [expectation], timeout: 1)
    }

    func testButtonTapOnHidden() async throws {
        let view = UIButton()
        view.setSize(width: 100, height: 100)
        view.backgroundColor = .green
        view.isHidden = true

        let eventGenerator = try await EventGenerator(view: view)
        try await eventGenerator.wait(0.5)

        do {
            try await eventGenerator.fingerTap()
            XCTFail("Button should not be tappable")
        } catch HammerError.viewIsNotVisible {
            // Success
        } catch {
            throw error
        }
    }

    func testButtonTapOnMinimumAlpha() async throws {
        let view = UIButton()
        view.setSize(width: 100, height: 100)
        view.backgroundColor = .green
        view.alpha = 0.0001

        let eventGenerator = try await EventGenerator(view: view)
        try await eventGenerator.wait(0.5)

        do {
            try await eventGenerator.fingerTap()
            XCTFail("Button should not be tappable")
        } catch HammerError.viewIsNotVisible {
            // Success
        } catch {
            throw error
        }
    }

    func testButtonTapOnNonInteractive() async throws {
        let view = UIButton()
        view.setSize(width: 100, height: 100)
        view.backgroundColor = .green
        view.isUserInteractionEnabled = false

        let eventGenerator = try await EventGenerator(view: view)
        try await eventGenerator.wait(0.5)

        do {
            try await eventGenerator.fingerTap()
            XCTFail("Button should not be tappable")
        } catch HammerError.viewIsNotHittable {
            // Success
        } catch {
            throw error
        }
    }

    func testButtonTapInsideOfBounds() async throws {
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

        let eventGenerator = try await EventGenerator(view: containerView)
        try await eventGenerator.waitUntilHittable(view, timeout: 1)
        try await eventGenerator.fingerTap(at: view)

        await self.fulfillment(of: [expectation], timeout: 1)
    }

    func testButtonTapOutOfBounds() async throws {
        let containerView = UIView()
        containerView.setSize(width: 100, height: 100)
        containerView.backgroundColor = .blue

        let view = UIButton()
        view.setSize(width: 100, height: 100)
        view.backgroundColor = .green
        containerView.addSubview(view)
        view.setOrigin(x: 0, y: 100)

        let eventGenerator = try await EventGenerator(view: containerView)
        try await eventGenerator.wait(0.5)

        do {
            try await eventGenerator.fingerTap(at: view)
            XCTFail("Button should not be tappable")
        } catch HammerError.viewIsNotHittable {
            // Success
        } catch {
            throw error
        }
    }

    func testButtonTapOutOfBoundsClipped() async throws {
        let containerView = UIView()
        containerView.setSize(width: 100, height: 100)
        containerView.backgroundColor = .blue
        containerView.clipsToBounds = true

        let view = UIButton()
        view.setSize(width: 100, height: 100)
        view.backgroundColor = .green
        containerView.addSubview(view)
        view.setOrigin(x: 0, y: 100)

        let eventGenerator = try await EventGenerator(view: containerView)
        try await eventGenerator.wait(0.5)

        do {
            try await eventGenerator.fingerTap(at: view)
            XCTFail("Button should not be tappable")
        } catch HammerError.viewIsNotVisible {
            // Success
        } catch {
            throw error
        }
    }

    func testButtonTapOnNonInteractiveSuperview() async throws {
        let view = UIButton()
        view.setSize(width: 100, height: 100)
        view.accessibilityIdentifier = "my_button"
        view.backgroundColor = .green

        let containerView = UIView()
        containerView.setSize(width: 100, height: 100)
        containerView.backgroundColor = .blue
        containerView.isUserInteractionEnabled = false
        containerView.addSubview(view)

        let eventGenerator = try await EventGenerator(view: containerView)
        try await eventGenerator.wait(0.5)

        do {
            try await eventGenerator.fingerTap(at: "my_button")
            XCTFail("Button should not be tappable")
        } catch HammerError.viewIsNotHittable {
            // Success
        } catch {
            throw error
        }
    }

    func testButtonTapOnCoveredButton() async throws {
        let containerView = UIView()
        containerView.setSize(width: 100, height: 100)

        let view = UIButton()
        view.setSize(width: 100, height: 100)
        view.accessibilityIdentifier = "my_button"
        containerView.addSubview(view)

        let coverView = UIButton()
        coverView.setSize(width: 100, height: 100)
        containerView.addSubview(coverView)

        let eventGenerator = try await EventGenerator(view: containerView)
        try await eventGenerator.wait(0.5)

        do {
            try await eventGenerator.fingerTap(at: "my_button")
            XCTFail("Button should not be tappable")
        } catch HammerError.viewIsNotHittable {
            // Success
        } catch {
            throw error
        }
    }

    func testButtonHighlight() async throws {
        let view = UIButton()
        view.setSize(width: 100, height: 100)
        view.backgroundColor = .green

        let touchDownExpectation = XCTestExpectation(description: "Button Touch Down")
        view.addHandler(forEvent: .touchDown, action: touchDownExpectation.fulfill)

        let touchUpExpectation = XCTestExpectation(description: "Button Touch Up")
        view.addHandler(forEvent: .touchUpInside, action: touchUpExpectation.fulfill)

        let eventGenerator = try await EventGenerator(view: view)
        try await eventGenerator.waitUntilHittable(timeout: 1)

        XCTAssertFalse(view.isHighlighted)
        try await eventGenerator.fingerDown()
        try await eventGenerator.wait(0.3)
        XCTAssertTrue(view.isHighlighted)
        try await eventGenerator.fingerUp()
        try await eventGenerator.wait(0.2)
        XCTAssertFalse(view.isHighlighted)

        await self.fulfillment(of: [touchDownExpectation, touchUpExpectation], timeout: 1)
    }

    func testViewTapGesture() async throws {
        let view = UIView()
        view.setSize(width: 100, height: 100)
        view.backgroundColor = .green

        let expectation = XCTestExpectation(description: "Button Tapped")
        let recognizer = UITapGestureRecognizer()
        recognizer.addHandler(forState: .recognized, action: expectation.fulfill)
        view.addGestureRecognizer(recognizer)

        let eventGenerator = try await EventGenerator(view: view)
        try await eventGenerator.waitUntilHittable(timeout: 1)
        try await eventGenerator.fingerTap()

        await self.fulfillment(of: [expectation], timeout: 1)
    }

    func testViewDoubleTapGesture() async throws {
        let view = UIView()
        view.setSize(width: 100, height: 100)
        view.backgroundColor = .green

        let expectation = XCTestExpectation(description: "Button Double Tapped")
        let recognizer = UITapGestureRecognizer()
        recognizer.numberOfTapsRequired = 2
        recognizer.addHandler(forState: .recognized, action: expectation.fulfill)
        view.addGestureRecognizer(recognizer)

        let eventGenerator = try await EventGenerator(view: view)
        try await eventGenerator.waitUntilHittable(timeout: 1)
        try await eventGenerator.fingerDoubleTap()

        await self.fulfillment(of: [expectation], timeout: 3)
    }

    func testViewTwoFingerTapGesture() async throws {
        let view = UIView()
        view.setSize(width: 100, height: 100)
        view.backgroundColor = .green

        let expectation = XCTestExpectation(description: "Button Two Finger Tapped")
        let recognizer = UITapGestureRecognizer()
        recognizer.numberOfTouchesRequired = 2
        recognizer.addHandler(forState: .recognized, action: expectation.fulfill)
        view.addGestureRecognizer(recognizer)

        let eventGenerator = try await EventGenerator(view: view)
        try await eventGenerator.waitUntilHittable(timeout: 1)
        try await eventGenerator.twoFingerTap()

        await self.fulfillment(of: [expectation], timeout: 3)
    }

    func testViewLongPressGesture() async throws {
        let view = UIView()
        view.setSize(width: 100, height: 100)
        view.backgroundColor = .green

        let expectation = XCTestExpectation(description: "Button Long Pressed")
        let recognizer = UILongPressGestureRecognizer()
        recognizer.addHandler(forState: .recognized, action: expectation.fulfill)
        view.addGestureRecognizer(recognizer)

        let eventGenerator = try await EventGenerator(view: view)
        try await eventGenerator.waitUntilHittable(timeout: 1)
        try await eventGenerator.fingerLongPress()

        await self.fulfillment(of: [expectation], timeout: 3)
    }

    func testViewRotationGesture() async throws {
        let view = UIView()
        view.setSize(width: 300, height: 300)
        view.backgroundColor = .green

        let expectation = XCTestExpectation(description: "View Rotated")
        let recognizer = UIRotationGestureRecognizer()
        recognizer.addHandler(forState: .recognized, action: expectation.fulfill)
        view.addGestureRecognizer(recognizer)

        let eventGenerator = try await EventGenerator(view: view)
        try await eventGenerator.waitUntilHittable(timeout: 1)
        try await eventGenerator.fingerRotate(angle: .pi, duration: 0.2)

        await self.fulfillment(of: [expectation], timeout: 3)
    }

    func testTwoFingerDownAtAngle() async throws {
        let view = TouchTestView()
        view.isMultipleTouchEnabled = true
        view.setSize(width: 300, height: 300)
        view.backgroundColor = .green

        let eventGenerator = try await EventGenerator(view: view)
        try await eventGenerator.waitUntilHittable(timeout: 1)
        try await eventGenerator.twoFingerDown(withDistance: 100, angle: .pi / 2)

        let locations = view.touches.map { $0.location(in: view) }.sorted { $0.y < $1.y }
        XCTAssertEqual(locations.count, 2)
        XCTAssertEqual(locations.first?.x ?? 0, 150, accuracy: 0.5)
        XCTAssertEqual(locations.first?.y ?? 0, 100, accuracy: 0.5)
        XCTAssertEqual(locations.last?.x ?? 0, 150, accuracy: 0.5)
        XCTAssertEqual(locations.last?.y ?? 0, 200, accuracy: 0.5)

        try await eventGenerator.twoFingerUp()
    }

    func testFingerUpKeepsOtherFingersDown() async throws {
        let view = TouchTestView()
        view.isMultipleTouchEnabled = true
        view.setSize(width: 300, height: 300)
        view.backgroundColor = .green

        let eventGenerator = try await EventGenerator(view: view)
        try await eventGenerator.waitUntilHittable(timeout: 1)
        try await eventGenerator.fingerDown([.rightThumb, .rightIndex],
                                            at: [OffsetLocation(x: -50, y: 0), OffsetLocation(x: 50, y: 0)])
        try await eventGenerator.fingerUp(.rightThumb)

        let touches = view.touches.sorted { $0.location(in: view).x < $1.location(in: view).x }
        XCTAssertEqual(touches.count, 2)
        let thumbTouch = try XCTUnwrap(touches.first)
        let indexTouch = try XCTUnwrap(touches.last)
        XCTAssertEqual(view.endedTouches, [thumbTouch])

        try await eventGenerator.fingerMove(.rightIndex, to: OffsetLocation(x: 100, y: 0))
        XCTAssertEqual(view.movedTouches, [indexTouch])
        XCTAssertEqual(indexTouch.location(in: view).x, 250, accuracy: 0.5)

        try await eventGenerator.fingerUp(.rightIndex)
        XCTAssertEqual(view.endedTouches, [thumbTouch, indexTouch])
    }

    func testSwitchToggle() async throws {
        let view = UISwitch()
        let eventGenerator = try await EventGenerator(view: view)
        try await eventGenerator.waitUntilHittable(timeout: 1)

        let expectation = XCTestExpectation(description: "Button Value Changed")
        view.addHandler(forEvent: .valueChanged, action: expectation.fulfill)

        XCTAssertFalse(view.isOn)
        try await eventGenerator.fingerTap()
        XCTAssertTrue(view.isOn)

        await self.fulfillment(of: [expectation], timeout: 1)
    }

    func testSwitchToggleOnOff() async throws {
        let view = UISwitch()
        let eventGenerator = try await EventGenerator(view: view)
        try await eventGenerator.waitUntilHittable(timeout: 1)

        XCTAssertFalse(view.isOn)
        try await eventGenerator.fingerDown(at: view.frame.center.offset(x: -20, y: 0))
        try await eventGenerator.fingerMove(to: view.frame.center.offset(x: 40, y: 0), duration: 0.5)
        try await eventGenerator.fingerUp()
        XCTAssertTrue(view.isOn)
        try await eventGenerator.fingerDown(at: view.frame.center.offset(x: 20, y: 0))
        try await eventGenerator.fingerMove(to: view.frame.center.offset(x: -40, y: 0), duration: 0.5)
        try await eventGenerator.fingerUp()
        XCTAssertFalse(view.isOn)
    }

    func testScrollViewDrag() async throws {
        let view = PatternScrollView()
        view.setSize(width: 300, height: 300)

        let eventGenerator = try await EventGenerator(view: view)
        try await eventGenerator.waitUntilHittable(timeout: 1)

        XCTAssertEqual(view.contentOffset, CGPoint(x: 0, y: 0))
        try await eventGenerator.fingerDrag(from: view.frame.center.offset(x: 40, y: 100),
                                      to: view.frame.center.offset(x: -40, y: -100),
                                      duration: 1)
        XCTAssertEqual(view.contentOffset, CGPoint(x: 75, y: 190), accuracy: 10)
    }

    func testScrollViewDragWithTranslation() async throws {
        let view = PatternScrollView()
        view.setSize(width: 300, height: 300)

        let eventGenerator = try await EventGenerator(view: view)
        try await eventGenerator.waitUntilHittable(timeout: 1)

        XCTAssertEqual(view.contentOffset, CGPoint(x: 0, y: 0))
        try await eventGenerator.fingerDown(at: view.frame.center.offset(x: 40, y: 100))
        try await eventGenerator.fingerMove(translationX: -80, y: -200, duration: 1)
        XCTAssertEqual(view.contentOffset, CGPoint(x: 75, y: 190), accuracy: 10)
    }

    func testScrollViewPinch() async throws {
        let view = PatternScrollView()
        view.setSize(width: 300, height: 300)

        let eventGenerator = try await EventGenerator(view: view)
        try await eventGenerator.waitUntilHittable(timeout: 1)

        try await eventGenerator.wait(0.3)
        XCTAssertEqual(view.zoomScale, 1)
        try await eventGenerator.fingerPinchOpen(duration: 1)
        try await eventGenerator.wait(0.3)
        XCTAssertEqual(view.zoomScale, 6.9, accuracy: 1)
        try await eventGenerator.fingerPinchClose(duration: 1)
        try await eventGenerator.wait(0.3)
        XCTAssertEqual(view.zoomScale, 1, accuracy: 0.1)
    }

    func testOffsetLocation() async throws {
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

        let eventGenerator = try await EventGenerator(view: view)
        try await eventGenerator.waitUntilHittable(view.subviews[0], timeout: 1)
        try await eventGenerator.fingerTap(at: OffsetLocation(x: -100, y: 0))
        try await eventGenerator.fingerTap(at: OffsetLocation(x: 0, y: 0))
        try await eventGenerator.fingerTap(at: OffsetLocation(x: 100, y: 0))

        await self.fulfillment(of: expectations, timeout: 1, enforceOrder: true)
    }

    func testRelativeLocation() async throws {
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

        let eventGenerator = try await EventGenerator(view: view)
        try await eventGenerator.waitUntilHittable(view.subviews[0], timeout: 1)
        try await eventGenerator.fingerTap(at: RelativeLocation(x: 0.2, y: 0.5))
        try await eventGenerator.fingerTap(at: RelativeLocation(x: 0.5, y: 0.5))
        try await eventGenerator.fingerTap(at: RelativeLocation(x: 0.8, y: 0.5))

        await self.fulfillment(of: expectations, timeout: 1, enforceOrder: true)
    }
}
