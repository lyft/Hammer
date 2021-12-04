import Hammer
import XCTest
import Foundation

final class DragTests: XCTestCase {

    func test_drag() throws {
        let view = TouchTestView()

        view.widthAnchor.constraint(equalToConstant: 300).isActive = true
        view.heightAnchor.constraint(equalToConstant: 300).isActive = true

        let eventGenerator = try EventGenerator(view: view)
        try eventGenerator.waitUntilHittable(timeout: 1)

        try eventGenerator.fingerDown(at: view.frame.center.offset(x: -50, y: 0))
        try eventGenerator.fingerMove(to: view.frame.center.offset(x: 50, y: 0), duration: 0.3)
        try eventGenerator.fingerUp()

        let endPoint = view.touches.first!.location(in: view)
        XCTAssertEqual(endPoint, CGPoint(x: 200, y: 150), accuracy: 0.001)
    }

}
