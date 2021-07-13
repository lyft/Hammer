import Hammer
import UIKit
import XCTest

final class HandTests: XCTestCase {
    func testButtonTap() throws {
        let view = UIButton(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        view.setContentHuggingPriority(.required, for: .vertical)
        view.setContentHuggingPriority(.required, for: .horizontal)
        view.backgroundColor = .green

        let expectation = XCTestExpectation(description: "Button Tapped")
        view.addHandler(forEvent: .primaryActionTriggered, action: expectation.fulfill)

        let eventGenerator = try EventGenerator(view: view)
        try eventGenerator.waitUntilHittable(timeout: 1)
        try eventGenerator.fingerTap()

        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 1), .completed)
    }

    func testButtonHighlight() throws {
        let view = UIButton(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        view.setContentHuggingPriority(.required, for: .vertical)
        view.setContentHuggingPriority(.required, for: .horizontal)
        view.backgroundColor = .green

        let touchDownExpectation = XCTestExpectation(description: "Button Touch Down")
        view.addHandler(forEvent: .touchDown, action: touchDownExpectation.fulfill)

        let touchUpExpectation = XCTestExpectation(description: "Button Touch Up")
        view.addHandler(forEvent: .touchUpInside, action: touchUpExpectation.fulfill)

        let eventGenerator = try EventGenerator(view: view)
        try eventGenerator.waitUntilHittable(timeout: 1)

        XCTAssertFalse(view.isHighlighted)
        try eventGenerator.fingerDown()
        XCTAssertTrue(view.isHighlighted)
        try eventGenerator.fingerUp()
        XCTAssertFalse(view.isHighlighted)

        XCTAssertEqual(XCTWaiter.wait(for: [touchDownExpectation, touchUpExpectation], timeout: 1),
                       .completed)
    }

    func testViewTapGesture() throws {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        view.setContentHuggingPriority(.required, for: .vertical)
        view.setContentHuggingPriority(.required, for: .horizontal)
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
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        view.setContentHuggingPriority(.required, for: .vertical)
        view.setContentHuggingPriority(.required, for: .horizontal)
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
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        view.setContentHuggingPriority(.required, for: .vertical)
        view.setContentHuggingPriority(.required, for: .horizontal)
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
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        view.setContentHuggingPriority(.required, for: .vertical)
        view.setContentHuggingPriority(.required, for: .horizontal)
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
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        view.setContentHuggingPriority(.required, for: .vertical)
        view.setContentHuggingPriority(.required, for: .horizontal)
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
        view.widthAnchor.constraint(equalToConstant: 300).isActive = true
        view.heightAnchor.constraint(equalToConstant: 300).isActive = true

        let eventGenerator = try EventGenerator(view: view)
        try eventGenerator.waitUntilHittable(timeout: 1)

        XCTAssertEqual(view.contentOffset, CGPoint(x: 0, y: 0))
        try eventGenerator.fingerDrag(from: view.frame.center.offset(x: 40, y: 100),
                                      to: view.frame.center.offset(x: -40, y: -100),
                                      duration: 1)
        XCTAssertEqual(view.contentOffset, CGPoint(x: 75, y: 190), accuracy: 2)
    }

    func testScrollViewPinch() throws {
        let view = PatternScrollView()
        view.widthAnchor.constraint(equalToConstant: 300).isActive = true
        view.heightAnchor.constraint(equalToConstant: 300).isActive = true

        let eventGenerator = try EventGenerator(view: view)
        try eventGenerator.waitUntilHittable(timeout: 1)

        try eventGenerator.wait(0.3)
        XCTAssertEqual(view.zoomScale, 1)
        try eventGenerator.fingerPinchOpen(duration: 1)
        try eventGenerator.wait(0.3)
        XCTAssertEqual(view.zoomScale, 6.9, accuracy: 1)
        try eventGenerator.wait(0.3)
        try eventGenerator.fingerPinchClose(duration: 1)
        XCTAssertEqual(view.zoomScale, 1, accuracy: 0.1)
    }
}
