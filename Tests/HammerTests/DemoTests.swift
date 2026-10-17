import Hammer
import UIKit
import XCTest
import MapKit

/// These are skipped by default because they're too slow
private let kSkipDemoTests = true

private let kMapDefaultCoordinate = CLLocationCoordinate2D(latitude: 37.773972, longitude: -122.431297)
private let kMapDefaultCoordinateDistance = CLLocationDistance(100000)
@MainActor
private let kMapDefaultCamera = MKMapCamera(lookingAtCenter: kMapDefaultCoordinate,
                                            fromDistance: kMapDefaultCoordinateDistance,
                                            pitch: 0, heading: 0)

/// These tests are used to generate the recording for the readme, too slow for normal testing
@MainActor
final class DemoTests: XCTestCase {
    func testASwitchToggleOnOff() async throws {
        try XCTSkipIf(kSkipDemoTests, "Demo tests are disabled")

        let view = UISwitch()
        let eventGenerator = try await EventGenerator(view: view)
        try await eventGenerator.waitUntilHittable(timeout: 1)
        try await eventGenerator.wait(0.5)

        XCTAssertEqual(view.isOn, false)
        try await eventGenerator.fingerDown(at: view.frame.center.offset(x: -20, y: 0))
        try await eventGenerator.fingerMove(to: view.frame.center.offset(x: 20, y: 0), duration: 1)
        try await eventGenerator.fingerUp()
        XCTAssertEqual(view.isOn, true)
        try await eventGenerator.fingerDown(at: view.frame.center.offset(x: 20, y: 0))
        try await eventGenerator.fingerMove(to: view.frame.center.offset(x: -40, y: 0), duration: 1)
        try await eventGenerator.fingerUp()
        XCTAssertEqual(view.isOn, false)
        try await eventGenerator.wait(1)
    }

    func testBTypeOnTextField() async throws {
        try XCTSkipIf(kSkipDemoTests, "Demo tests are disabled")

        let view = UITextField()
        view.textAlignment = .center
        view.autocapitalizationType = .none
        view.setSize(width: 300)
        let eventGenerator = try await EventGenerator(view: view)
        try await eventGenerator.waitUntilHittable(timeout: 1)
        try await eventGenerator.wait(0.5)

        view.becomeFirstResponder()
        XCTAssertEqual(view.isFirstResponder, true)

        let text1 = "I can type in a text field!"
        let text2 = "Symbols too! @#$%"
        try await eventGenerator.keyType(text1)
        try await eventGenerator.wait(0.5)
        try await eventGenerator.keyPress(.deleteOrBackspace, numberOfTimes: text1.count)
        try await eventGenerator.keyType(text2)
        try await eventGenerator.wait(0.5)
    }

    func testCMapDrag() async throws {
        try XCTSkipIf(kSkipDemoTests, "Demo tests are disabled")

        let view = MapView()
        view.setSize(width: 600, height: 300)

        let eventGenerator = try await EventGenerator(view: view)
        try await eventGenerator.waitUntilHittable(timeout: 1)
        try await eventGenerator.wait(0.5)
        try await eventGenerator.fingerDrag(from: view.frame.center.offset(x: -20, y: -100),
                                      to: view.frame.center.offset(x: 20, y: 100),
                                      duration: 1)
        try await eventGenerator.wait(0.5)
        try await eventGenerator.fingerPinchOpen(at: view.frame.center, duration: 2)
        try await eventGenerator.wait(0.5)
        try await eventGenerator.fingerPinchClose(at: view.frame.center, duration: 2)
        try await eventGenerator.wait(0.5)
        try await eventGenerator.fingerRotate(at: view.frame.center, angle: .pi/2, duration: 2)
        try await eventGenerator.wait(0.5)
        try await eventGenerator.fingerRotate(at: view.frame.center, angle: -.pi, duration: 2)
        try await eventGenerator.wait(0.5)
    }
}

private final class MapView: MKMapView {
    init() {
        super.init(frame: .zero)
        self.showsCompass = false
        self.showsUserLocation = false
        self.setCamera(kMapDefaultCamera, animated: false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
