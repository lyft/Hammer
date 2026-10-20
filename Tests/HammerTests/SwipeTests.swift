import Hammer
import UIKit
import XCTest

@MainActor
final class SwipeTests: XCTestCase {
    func testSwipeGestureRecognizer() async throws {
        let view = UIView()
        view.setSize(width: 300, height: 300)

        let eventGenerator = try await EventGenerator(view: view)
        try await eventGenerator.waitUntilHittable(timeout: 1)

        for direction in SwipeDirection.allCases {
            let recognizer = UISwipeGestureRecognizer()
            recognizer.direction = direction.gestureDirection
            view.addGestureRecognizer(recognizer)

            let expectation = XCTestExpectation(description: "Swiped \(direction)")
            recognizer.addHandler(forState: .recognized, action: expectation.fulfill)

            try await eventGenerator.fingerSwipe(direction: direction)
            await self.fulfillment(of: [expectation], timeout: 1)
            view.removeGestureRecognizer(recognizer)
        }
    }

    func testSwipeScrollView() async throws {
        let view = PatternScrollView()
        view.setSize(width: 300, height: 300)

        let eventGenerator = try await EventGenerator(view: view)
        try await eventGenerator.waitUntilHittable(timeout: 1)

        XCTAssertEqual(view.contentOffset, .zero)
        try await eventGenerator.fingerSwipe(direction: .up)
        XCTAssertGreaterThan(view.contentOffset.y, 0)
        XCTAssertEqual(view.contentOffset.x, 0)
    }

    func testEdgeSwipeNavigatesBack() async throws {
        let navigationController = UINavigationController()
        navigationController.viewControllers = [UIViewController(), UIViewController()]
        let eventGenerator = try await EventGenerator(viewController: navigationController)
        try await eventGenerator.waitUntilHittable(timeout: 1)

        try await eventGenerator.fingerEdgeSwipe(direction: .right)
        try await eventGenerator.waitUntil(navigationController.viewControllers.count == 1, timeout: 1)
    }

    func testEdgeSwipeGestureRecognizer() async throws {
        let view = UIView()
        view.setSize(width: 300, height: 300)

        let eventGenerator = try await EventGenerator(view: view, alignment: .fill)
        try await eventGenerator.waitUntilHittable(timeout: 1)

        let recognizer = UIScreenEdgePanGestureRecognizer()
        recognizer.edges = .right
        view.addGestureRecognizer(recognizer)

        var beganCount = 0
        recognizer.addHandler(forState: .began) { beganCount += 1 }

        try await eventGenerator.fingerSwipe(direction: .left)
        XCTAssertEqual(beganCount, 0)
        try await eventGenerator.fingerEdgeSwipe(direction: .left)
        XCTAssertEqual(beganCount, 1)
    }
}

extension SwipeDirection {
    fileprivate var gestureDirection: UISwipeGestureRecognizer.Direction {
        switch self {
        case .up:
            return .up
        case .down:
            return .down
        case .left:
            return .left
        case .right:
            return .right
        }
    }
}
