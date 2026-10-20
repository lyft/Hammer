import Hammer
import UIKit
import XCTest

@MainActor
final class OrientationTests: XCTestCase {
    override func tearDown() async throws {
        try await self.rotate(to: .portrait)
        try await super.tearDown()
    }

    func testTapPointInLandscape() async throws {
        for orientation in [UIInterfaceOrientationMask.landscapeLeft, .landscapeRight] {
            let view = TouchTestView()
            let eventGenerator = try await EventGenerator(view: view, alignment: .fill)
            try await self.rotate(to: orientation)
            try await eventGenerator.waitUntilHittable(timeout: 1)
            XCTAssertGreaterThan(eventGenerator.window.bounds.width, eventGenerator.window.bounds.height)

            let point = CGPoint(x: eventGenerator.window.bounds.width - 60, y: 40)
            try await eventGenerator.fingerTap(at: point)
            let location = try XCTUnwrap(view.touches.first).location(in: view)
            XCTAssertEqual(view.convert(location, to: eventGenerator.window), point, accuracy: 1)
            try await eventGenerator.finish()
        }
    }

    func testTapButtonInLandscape() async throws {
        let button = UIButton(type: .system)
        button.setTitle("Landscape", for: .normal)
        button.accessibilityIdentifier = "my_button"

        let expectation = XCTestExpectation(description: "Button Tapped")
        button.addHandler(forEvent: .primaryActionTriggered, action: expectation.fulfill)

        let containerView = UIView()
        containerView.addSubview(button)
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -40),
            button.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -40),
        ])

        let eventGenerator = try await EventGenerator(view: containerView, alignment: .fill)
        try await self.rotate(to: .landscapeRight)
        try await eventGenerator.waitUntilHittable("my_button", timeout: 1)
        try await eventGenerator.fingerTap(at: "my_button")
        await self.fulfillment(of: [expectation], timeout: 1)
    }

    private func rotate(to orientation: UIInterfaceOrientationMask) async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: orientation))
        let predicate = NSPredicate { _, _ in
            MainActor.assumeIsolated {
                let current = scene.interfaceOrientation.rawValue
                return orientation.contains(UIInterfaceOrientationMask(rawValue: 1 << current))
            }
        }

        await self.fulfillment(of: [XCTNSPredicateExpectation(predicate: predicate, object: nil)], timeout: 3)
    }
}
