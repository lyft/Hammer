import Hammer
import MapKit
import UIKit
import XCTest

/// These are skipped by default because they are flaky
private let kSkipMapTests = true

private let kMapDefaultCoordinate = CLLocationCoordinate2D(latitude: 37.773972, longitude: -122.431297)
private let kMapDefaultCoordinateDistance = CLLocationDistance(100000)
private let kMapDefaultCamera = MKMapCamera(lookingAtCenter: kMapDefaultCoordinate,
                                            fromDistance: kMapDefaultCoordinateDistance,
                                            pitch: 0, heading: 0)

final class MapTests: XCTestCase {
    func testMapDrag() throws {
        try XCTSkipIf(kSkipMapTests, "Map tests are disabled because of flakiness")

        let view = MapView()
        view.widthAnchor.constraint(equalToConstant: 300).isActive = true
        view.heightAnchor.constraint(equalToConstant: 300).isActive = true

        let eventGenerator = try EventGenerator(view: view)
        try eventGenerator.waitUntilHittable(timeout: 1)
        XCTAssertEqual(view.camera.centerCoordinate, kMapDefaultCoordinate, accuracy: 0.001)
        try eventGenerator.fingerDrag(from: view.frame.center.offset(x: -20, y: -100),
                                      to: view.frame.center.offset(x: 20, y: 100),
                                      duration: 1)
        try eventGenerator.wait(0.5)
        let newCoordinate = CLLocationCoordinate2D(latitude: 38.07913, longitude: -122.50843)
        XCTAssertEqual(view.camera.centerCoordinate, newCoordinate, accuracy: 0.01)
    }

    func testMapDoubleTap() throws {
        try XCTSkipIf(kSkipMapTests, "Map tests are disabled because of flakiness")

        let view = MapView()
        view.widthAnchor.constraint(equalToConstant: 300).isActive = true
        view.heightAnchor.constraint(equalToConstant: 300).isActive = true

        let eventGenerator = try EventGenerator(view: view)
        try eventGenerator.waitUntilHittable(timeout: 1)
        XCTAssertEqual(view.camera.altitude, kMapDefaultCoordinateDistance, accuracy: 1)
        try eventGenerator.fingerDoubleTap(at: view.frame.center, interval: 0.1)
        try eventGenerator.wait(0.5)
        XCTAssertEqual(view.camera.altitude, 67445, accuracy: 50)
        try eventGenerator.twoFingerTap(at: view.frame.center)
        try eventGenerator.wait(0.5)
        XCTAssertEqual(view.camera.altitude, 134889, accuracy: 50)
    }

    func testMapPinch() throws {
        try XCTSkipIf(kSkipMapTests, "Map tests are disabled because of flakiness")

        let view = MapView()
        view.widthAnchor.constraint(equalToConstant: 300).isActive = true
        view.heightAnchor.constraint(equalToConstant: 300).isActive = true

        let eventGenerator = try EventGenerator(view: view)
        try eventGenerator.waitUntilHittable(timeout: 1)
        XCTAssertEqual(view.camera.altitude, kMapDefaultCoordinateDistance, accuracy: 1)
        try eventGenerator.fingerPinchOpen(at: view.frame.center, duration: 1)
        try eventGenerator.wait(0.5)
        XCTAssertEqual(view.camera.altitude, 14000, accuracy: 50)
        try eventGenerator.fingerPinchClose(at: view.frame.center, duration: 1)
        try eventGenerator.wait(0.5)
        XCTAssertEqual(view.camera.altitude, 134400, accuracy: 50)
    }

    func testMapRotate() throws {
        try XCTSkipIf(kSkipMapTests, "Map tests are disabled because of flakiness")

        let view = MapView()
        view.widthAnchor.constraint(equalToConstant: 300).isActive = true
        view.heightAnchor.constraint(equalToConstant: 300).isActive = true

        let eventGenerator = try EventGenerator(view: view)
        try eventGenerator.waitUntilHittable(timeout: 1)
        XCTAssertEqual(view.camera.heading, 0, accuracy: 1)
        try eventGenerator.fingerRotate(at: view.frame.center, angle: .pi/2, duration: 1)
        try eventGenerator.wait(0.5)
        XCTAssertEqual(view.camera.heading, 275, accuracy: 3)
        try eventGenerator.fingerRotate(at: view.frame.center, angle: -.pi, duration: 1)
        try eventGenerator.wait(0.5)
        XCTAssertEqual(view.camera.heading, 90, accuracy: 3)
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
