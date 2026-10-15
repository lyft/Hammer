@testable import Hammer
import UIKit
import XCTest

final class LifecycleTests: XCTestCase {
    private var originalSettings = EventGenerator.settings

    override func setUp() {
        super.setUp()
        self.originalSettings = EventGenerator.settings
        EventGenerator.settings.windowReadyTimeout = 0.3
    }

    override func tearDown() {
        EventGenerator.settings = self.originalSettings
        super.tearDown()
    }

    func testNotReadyErrorIncludesReason() throws {
        UIApplication.shared.beginIgnoringInteractionEvents()
        defer { UIApplication.shared.endIgnoringInteractionEvents() }

        let view = UIButton().withSize(width: 100, height: 100)
        XCTAssertThrowsError(try EventGenerator(view: view)) { error in
            guard case HammerError.windowIsNotReadyForInteraction(let reason) = error else {
                return XCTFail("Unexpected error: \(error)")
            }

            XCTAssertEqual(reason, .applicationIsIgnoringInteractionEvents)
            XCTAssertTrue("\(error)".contains("the application is ignoring interaction events"))
        }
    }

    func testWaitUntilClosureThrowsOnTimeout() throws {
        let eventGenerator = try EventGenerator(view: UIButton().withSize(width: 100, height: 100))
        XCTAssertThrowsError(try eventGenerator.waitUntil({ _ in }, timeout: 0.1)) { error in
            guard case HammerError.waitConditionTimeout = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }
}

extension UIView {
    fileprivate func withSize(width: CGFloat, height: CGFloat) -> Self {
        self.setSize(width: width, height: height)
        return self
    }
}
