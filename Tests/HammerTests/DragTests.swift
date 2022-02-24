import Hammer
import XCTest
import Foundation

final class DragTests: XCTestCase {

    func test_drag() throws {
        let view = TouchTestView()
        view.setSize(width: 300, height: 300)

        let eventGenerator = try EventGenerator(view: view)
        try eventGenerator.waitUntilHittable(timeout: 1)

        try eventGenerator.fingerDown(at: view.frame.center.offset(x: -50, y: 0))
        try eventGenerator.fingerMove(to: view.frame.center.offset(x: 50, y: 0), duration: 0.3)
        try eventGenerator.fingerUp()

        let endPoint = view.touches.first!.location(in: view)
        XCTAssertEqual(endPoint, CGPoint(x: 200, y: 150), accuracy: 0.001)
    }

}
