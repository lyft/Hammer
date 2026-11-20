@testable import HammerAgent
import UIKit
import XCTest

@MainActor
final class SystemAlertsTests: XCTestCase {
    func testAlertIsShowingWhenTheSceneCantShowAlerts() {
        XCTAssertTrue(SystemAlerts.isShowing(over: FakeScene(settings: FakeSettings(canShowAlerts: false))))
    }

    func testNoAlertWhenTheSceneCanShowAlerts() {
        XCTAssertFalse(SystemAlerts.isShowing(over: FakeScene(settings: FakeSettings(canShowAlerts: true))))
    }

    func testNoAlertWhenTheSettingIsMissing() {
        XCTAssertFalse(SystemAlerts.isShowing(over: FakeScene(settings: NSObject())))
    }

    func testNoAlertWhenTheSceneHasNoFrontBoardScene() {
        XCTAssertFalse(SystemAlerts.isShowing(over: NSObject()))
    }

    func testNoAlertOverTheTestHost() throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        XCTAssertFalse(SystemAlerts.isShowing(over: scene))
    }
}

private final class FakeSettings: NSObject {
    @objc let canShowAlerts: Bool

    init(canShowAlerts: Bool) {
        self.canShowAlerts = canShowAlerts
    }
}

private final class FakeFrontBoardScene: NSObject {
    private let fakeSettings: NSObject

    init(settings: NSObject) {
        self.fakeSettings = settings
    }

    @objc
    func settings() -> NSObject {
        return self.fakeSettings
    }
}

private final class FakeScene: NSObject {
    private let frontBoardScene: FakeFrontBoardScene

    init(settings: NSObject) {
        self.frontBoardScene = FakeFrontBoardScene(settings: settings)
    }

    @objc(_FBSScene)
    func fakeFrontBoardScene() -> NSObject {
        return self.frontBoardScene
    }
}
