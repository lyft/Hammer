import Hammer
import XCTest
import Foundation

@MainActor
final class DragTests: XCTestCase {

    func test_drag() async throws {
        let view = TouchTestView()
        view.setSize(width: 300, height: 300)

        let eventGenerator = try await EventGenerator(view: view)
        try await eventGenerator.waitUntilHittable(timeout: 1)

        try await eventGenerator.fingerDown(at: view.frame.center.offset(x: -50, y: 0))
        try await eventGenerator.fingerMove(to: view.frame.center.offset(x: 50, y: 0), duration: 0.3)
        try await eventGenerator.fingerUp()

        let endPoint = view.touches.first!.location(in: view)
        XCTAssertEqual(endPoint, CGPoint(x: 200, y: 150), accuracy: 0.001)
    }

}
