import Hammer
import UIKit
import XCTest

final class StylusTests: XCTestCase {
    func testButtonTap() throws {
        try XCTSkipUnless(UIDevice.current.supportsStylus, "Stylus tests only run on iPad")

        let expectation = XCTestExpectation(description: "Button Tapped")

        let view = UIButton(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        view.addHandler(forEvent: .primaryActionTriggered, action: expectation.fulfill)

        view.setContentHuggingPriority(.required, for: .vertical)
        view.setContentHuggingPriority(.required, for: .horizontal)
        view.backgroundColor = .green

        let eventGenerator = try EventGenerator(view: view)
        try eventGenerator.waitUntilHittable(timeout: 1)
        try eventGenerator.stylusTap()

        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 1), .completed)
    }

    func testButtonHighlight() throws {
        try XCTSkipUnless(UIDevice.current.supportsStylus, "Stylus tests only run on iPad")

        let view = UIButton(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        view.setContentHuggingPriority(.required, for: .vertical)
        view.setContentHuggingPriority(.required, for: .horizontal)
        view.backgroundColor = .green

        let eventGenerator = try EventGenerator(view: view)
        try eventGenerator.waitUntilHittable(timeout: 1)

        XCTAssertFalse(view.isHighlighted)
        try eventGenerator.stylusDown()
        XCTAssertTrue(view.isHighlighted)
        try eventGenerator.stylusUp()
        XCTAssertFalse(view.isHighlighted)
    }

    func testStylusMovesContinueFromLastLocation() throws {
        try XCTSkipUnless(UIDevice.current.supportsStylus, "Stylus tests only run on iPad")

        let view = UIView()
        view.setSize(width: 300, height: 300)
        let recorder = PanRecorder()
        let recognizer = UIPanGestureRecognizer(target: recorder, action: #selector(PanRecorder.pan))
        view.addGestureRecognizer(recognizer)

        let eventGenerator = try EventGenerator(view: view)
        try eventGenerator.waitUntilHittable(timeout: 1)

        try eventGenerator.stylusDown(at: RelativeLocation(x: 0.2, y: 0.5))
        try eventGenerator.stylusMove(to: RelativeLocation(x: 0.5, y: 0.5), duration: 0.2)
        try eventGenerator.stylusMove(to: RelativeLocation(x: 0.8, y: 0.5), duration: 0.2)
        try eventGenerator.stylusUp()

        let horizontalLocations = recorder.locations.map(\.x)
        XCTAssertFalse(horizontalLocations.isEmpty)
        XCTAssertEqual(horizontalLocations, horizontalLocations.sorted())
    }

    func testSwitchToggle() throws {
        try XCTSkipUnless(UIDevice.current.supportsStylus, "Stylus tests only run on iPad")

        let view = UISwitch()
        let eventGenerator = try EventGenerator(view: view)
        try eventGenerator.waitUntilHittable(timeout: 1)

        XCTAssertFalse(view.isOn)
        try eventGenerator.stylusTap()
        XCTAssertTrue(view.isOn)
    }

    func testSwitchToggleOnOff() throws {
        try XCTSkipUnless(UIDevice.current.supportsStylus, "Stylus tests only run on iPad")

        let view = UISwitch()
        let eventGenerator = try EventGenerator(view: view)
        try eventGenerator.waitUntilHittable(timeout: 1)

        XCTAssertFalse(view.isOn)
        try eventGenerator.stylusDown(at: view.frame.center.offset(x: -20, y: 0))
        try eventGenerator.stylusMove(to: view.frame.center.offset(x: 40, y: 0), duration: 0.5)
        try eventGenerator.stylusUp()
        XCTAssertTrue(view.isOn)
        try eventGenerator.stylusDown(at: view.frame.center.offset(x: 20, y: 0))
        try eventGenerator.stylusMove(to: view.frame.center.offset(x: -40, y: 0), duration: 0.5)
        try eventGenerator.stylusUp()
        XCTAssertFalse(view.isOn)
    }
}

private final class PanRecorder: NSObject {
    private(set) var locations: [CGPoint] = []

    @objc
    func pan(_ recognizer: UIPanGestureRecognizer) {
        self.locations.append(recognizer.location(in: recognizer.view))
    }
}
