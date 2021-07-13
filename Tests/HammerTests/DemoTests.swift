import Hammer
import UIKit
import XCTest
import MapKit

/// These are skipped by default because they're too slow
private let kSkipDemoTests = true

private let kMapDefaultCoordinate = CLLocationCoordinate2D(latitude: 37.773972, longitude: -122.431297)
private let kMapDefaultCoordinateDistance = CLLocationDistance(100000)
private let kMapDefaultCamera = MKMapCamera(lookingAtCenter: kMapDefaultCoordinate,
                                            fromDistance: kMapDefaultCoordinateDistance,
                                            pitch: 0, heading: 0)

/// These tests are used to generate the recording for the readme, too slow for normal testing
final class DemoTests: XCTestCase {
    func testASwitchToggleOnOff() throws {
        try XCTSkipIf(kSkipDemoTests, "Demo tests are disabled")

        let view = UISwitch()
        let eventGenerator = try EventGenerator(view: view)
        try eventGenerator.waitUntilHittable(timeout: 1)
        try eventGenerator.wait(0.5)

        XCTAssertEqual(view.isOn, false)
        try eventGenerator.fingerDown(at: view.frame.center.offset(x: -20, y: 0))
        try eventGenerator.fingerMove(to: view.frame.center.offset(x: 20, y: 0), duration: 1)
        try eventGenerator.fingerUp()
        XCTAssertEqual(view.isOn, true)
        try eventGenerator.fingerDown(at: view.frame.center.offset(x: 20, y: 0))
        try eventGenerator.fingerMove(to: view.frame.center.offset(x: -40, y: 0), duration: 1)
        try eventGenerator.fingerUp()
        XCTAssertEqual(view.isOn, false)
        try eventGenerator.wait(1)
    }

    func testBTypeOnTextField() throws {
        try XCTSkipIf(kSkipDemoTests, "Demo tests are disabled")

        let view = UITextField()
        view.textAlignment = .center
        view.autocapitalizationType = .none
        view.widthAnchor.constraint(equalToConstant: 300).isActive = true
        let eventGenerator = try EventGenerator(view: view)
        try eventGenerator.waitUntilHittable(timeout: 1)
        try eventGenerator.wait(0.5)

        view.becomeFirstResponder()
        XCTAssertEqual(view.isFirstResponder, true)

        let text1 = "I can type in a text field!"
        let text2 = "Symbols too! @#$%"
        try eventGenerator.keyType(text1)
        try eventGenerator.wait(0.5)
        try eventGenerator.keyPress(.deleteOrBackspace, numberOfTimes: text1.count)
        try eventGenerator.keyType(text2)
        try eventGenerator.wait(0.5)
    }

    func testCMapDrag() throws {
        try XCTSkipIf(kSkipDemoTests, "Demo tests are disabled")

        let view = MapView()
        view.widthAnchor.constraint(equalToConstant: 600).isActive = true
        view.heightAnchor.constraint(equalToConstant: 300).isActive = true

        let eventGenerator = try EventGenerator(view: view)
        try eventGenerator.waitUntilHittable(timeout: 1)
        try eventGenerator.wait(0.5)
        try eventGenerator.fingerDrag(from: view.frame.center.offset(x: -20, y: -100),
                                      to: view.frame.center.offset(x: 20, y: 100),
                                      duration: 1)
        try eventGenerator.wait(0.5)
        try eventGenerator.fingerPinchOpen(at: view.frame.center, duration: 2)
        try eventGenerator.wait(0.5)
        try eventGenerator.fingerPinchClose(at: view.frame.center, duration: 2)
        try eventGenerator.wait(0.5)
        try eventGenerator.fingerRotate(at: view.frame.center, angle: .pi/2, duration: 2)
        try eventGenerator.wait(0.5)
        try eventGenerator.fingerRotate(at: view.frame.center, angle: -.pi, duration: 2)
        try eventGenerator.wait(0.5)
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
