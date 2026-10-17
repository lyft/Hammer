import Hammer
import UIKit
import XCTest

@MainActor
final class StylusTests: XCTestCase {
    func testButtonTap() async throws {
        try XCTSkipUnless(UIDevice.current.supportsStylus, "Stylus tests only run on iPad")

        let expectation = XCTestExpectation(description: "Button Tapped")

        let view = UIButton(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        view.addHandler(forEvent: .primaryActionTriggered, action: expectation.fulfill)

        view.setContentHuggingPriority(.required, for: .vertical)
        view.setContentHuggingPriority(.required, for: .horizontal)
        view.backgroundColor = .green

        let eventGenerator = try await EventGenerator(view: view)
        try await eventGenerator.waitUntilHittable(timeout: 1)
        try await eventGenerator.stylusTap()

        await self.fulfillment(of: [expectation], timeout: 1)
    }

    func testButtonHighlight() async throws {
        try XCTSkipUnless(UIDevice.current.supportsStylus, "Stylus tests only run on iPad")

        let view = UIButton(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        view.setContentHuggingPriority(.required, for: .vertical)
        view.setContentHuggingPriority(.required, for: .horizontal)
        view.backgroundColor = .green

        let eventGenerator = try await EventGenerator(view: view)
        try await eventGenerator.waitUntilHittable(timeout: 1)

        XCTAssertFalse(view.isHighlighted)
        try await eventGenerator.stylusDown()
        XCTAssertTrue(view.isHighlighted)
        try await eventGenerator.stylusUp()
        XCTAssertFalse(view.isHighlighted)
    }

    func testStylusMovesContinueFromLastLocation() async throws {
        try XCTSkipUnless(UIDevice.current.supportsStylus, "Stylus tests only run on iPad")

        let view = UIView()
        view.setSize(width: 300, height: 300)
        let recorder = PanRecorder()
        let recognizer = UIPanGestureRecognizer(target: recorder, action: #selector(PanRecorder.pan))
        view.addGestureRecognizer(recognizer)

        let eventGenerator = try await EventGenerator(view: view)
        try await eventGenerator.waitUntilHittable(timeout: 1)

        try await eventGenerator.stylusDown(at: RelativeLocation(x: 0.2, y: 0.5))
        try await eventGenerator.stylusMove(to: RelativeLocation(x: 0.5, y: 0.5), duration: 0.2)
        try await eventGenerator.stylusMove(to: RelativeLocation(x: 0.8, y: 0.5), duration: 0.2)
        try await eventGenerator.stylusUp()

        let horizontalLocations = recorder.locations.map(\.x)
        XCTAssertFalse(horizontalLocations.isEmpty)
        XCTAssertEqual(horizontalLocations, horizontalLocations.sorted())
    }

    func testSwitchToggle() async throws {
        try XCTSkipUnless(UIDevice.current.supportsStylus, "Stylus tests only run on iPad")

        let view = UISwitch()
        let eventGenerator = try await EventGenerator(view: view)
        try await eventGenerator.waitUntilHittable(timeout: 1)

        XCTAssertFalse(view.isOn)
        try await eventGenerator.stylusTap()
        XCTAssertTrue(view.isOn)
    }

    func testSwitchToggleOnOff() async throws {
        try XCTSkipUnless(UIDevice.current.supportsStylus, "Stylus tests only run on iPad")

        let view = UISwitch()
        let eventGenerator = try await EventGenerator(view: view)
        try await eventGenerator.waitUntilHittable(timeout: 1)

        XCTAssertFalse(view.isOn)
        try await eventGenerator.stylusDown(at: view.frame.center.offset(x: -20, y: 0))
        try await eventGenerator.stylusMove(to: view.frame.center.offset(x: 40, y: 0), duration: 0.5)
        try await eventGenerator.stylusUp()
        XCTAssertTrue(view.isOn)
        try await eventGenerator.stylusDown(at: view.frame.center.offset(x: 20, y: 0))
        try await eventGenerator.stylusMove(to: view.frame.center.offset(x: -40, y: 0), duration: 0.5)
        try await eventGenerator.stylusUp()
        XCTAssertFalse(view.isOn)
    }
}

@MainActor
private final class PanRecorder: NSObject {
    private(set) var locations: [CGPoint] = []

    @objc
    func pan(_ recognizer: UIPanGestureRecognizer) {
        self.locations.append(recognizer.location(in: recognizer.view))
    }
}
