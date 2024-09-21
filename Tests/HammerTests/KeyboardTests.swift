@testable import Hammer
import UIKit
import XCTest

final class KeyboardTests: XCTestCase {
    func testTypeOnTextField() throws {
        let view = UITextField()
        view.setSize(width: 300)
        view.disablePredictiveBar()
        view.autocapitalizationType = .none

        let eventGenerator = try EventGenerator(view: view)
        try eventGenerator.waitUntilHittable(timeout: 1)

        try eventGenerator.fingerTap()
        XCTAssertTrue(view.isFirstResponder)

        XCTAssertEqual(view.text, "")
        try eventGenerator.keyType("abc")
        XCTAssertEqual(view.text, "abc")
    }

    func testKeyOnTextField() throws {
        let view = UITextField()
        view.setSize(width: 300)
        view.disablePredictiveBar()
        view.autocapitalizationType = .none

        let eventGenerator = try EventGenerator(view: view)
        try eventGenerator.waitUntilHittable(timeout: 1)

        try eventGenerator.fingerTap()
        XCTAssertTrue(view.isFirstResponder)

        XCTAssertEqual(view.text, "")
        try eventGenerator.keyDown("a")
        try eventGenerator.keyUp("a")
        XCTAssertEqual(view.text, "a")
    }

    func testUppercaseCharacters() throws {
        let keys = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

        let view = UITextField()
        view.setSize(width: 300)
        view.disablePredictiveBar()
        view.smartQuotesType = .no

        let eventGenerator = try EventGenerator(view: view)
        try eventGenerator.waitUntilHittable(timeout: 1)

        try eventGenerator.fingerTap()
        XCTAssertTrue(view.isFirstResponder)

        XCTAssertEqual(view.text, "")
        try eventGenerator.keyType(keys)
        XCTAssertEqual(view.text, keys)
    }

    func testLowercaseCharacters() throws {
        let keys = "abcdefghijklmnopqrstuvwxyz"

        let view = UITextField()
        view.setSize(width: 300)
        view.disablePredictiveBar()
        view.smartQuotesType = .no
        view.autocapitalizationType = .none

        let eventGenerator = try EventGenerator(view: view)
        try eventGenerator.waitUntilHittable(timeout: 1)

        try eventGenerator.fingerTap()
        XCTAssertTrue(view.isFirstResponder)

        XCTAssertEqual(view.text, "")
        try eventGenerator.keyType(keys)
        XCTAssertEqual(view.text, keys)
    }

    func testNumberCharacters() throws {
        let keys = "0123456789"

        let view = UITextField()
        view.setSize(width: 300)
        view.disablePredictiveBar()
        view.smartQuotesType = .no

        let eventGenerator = try EventGenerator(view: view)
        try eventGenerator.waitUntilHittable(timeout: 1)

        try eventGenerator.fingerTap()
        XCTAssertTrue(view.isFirstResponder)

        XCTAssertEqual(view.text, "")
        try eventGenerator.keyType(keys)
        XCTAssertEqual(view.text, keys)
    }

    func testSymbolCharacters() throws {
        let keys = "-=,./;'[]\\"

        let view = UITextField()
        view.setSize(width: 300)
        view.disablePredictiveBar()
        view.smartQuotesType = .no

        let eventGenerator = try EventGenerator(view: view)
        try eventGenerator.waitUntilHittable(timeout: 1)

        try eventGenerator.fingerTap()
        XCTAssertTrue(view.isFirstResponder)

        XCTAssertEqual(view.text, "")
        try eventGenerator.keyType(keys)
        XCTAssertEqual(view.text, keys)
    }

    func testShiftCharacters() throws {
        let keys = "!@#$%^&*()_+{}|:\"<>?~"

        let view = UITextField()
        view.setSize(width: 300)
        view.disablePredictiveBar()
        view.smartQuotesType = .no

        let eventGenerator = try EventGenerator(view: view)
        try eventGenerator.waitUntilHittable(timeout: 1)

        try eventGenerator.fingerTap()
        XCTAssertTrue(view.isFirstResponder)

        XCTAssertEqual(view.text, "")
        try eventGenerator.keyType(keys)
        XCTAssertEqual(view.text, keys)
    }

    func testSpaceCharacter() throws {
        let keys = "a a"

        let view = UITextField()
        view.setSize(width: 300)
        view.disablePredictiveBar()
        view.autocapitalizationType = .none

        let eventGenerator = try EventGenerator(view: view)
        try eventGenerator.waitUntilHittable(timeout: 1)

        try eventGenerator.fingerTap()
        XCTAssertTrue(view.isFirstResponder)

        XCTAssertEqual(view.text, "")
        try eventGenerator.keyType(keys)
        XCTAssertEqual(view.text, keys)
    }

    func testNewlineCharacters() throws {
        let keys = "a\na\ra"
        let result = "a\na\na"

        let view = UITextView()
        view.setSize(width: 300, height: 300)
        view.disablePredictiveBar()
        view.autocapitalizationType = .none

        let eventGenerator = try EventGenerator(view: view)
        try eventGenerator.waitUntilHittable(timeout: 1)

        try eventGenerator.fingerTap()
        XCTAssertTrue(view.isFirstResponder)

        XCTAssertEqual(view.text, "")
        try eventGenerator.keyType(keys)
        XCTAssertEqual(view.text, result)
    }

    func testEnsureKeyWindowError() throws {
        let view = UITextField()
        view.setSize(width: 300)
        view.disablePredictiveBar()
        view.autocapitalizationType = .none

        let viewController = UIViewController()
        viewController.view.addSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.centerYAnchor.constraint(equalTo: viewController.view.centerYAnchor),
            view.centerXAnchor.constraint(equalTo: viewController.view.centerXAnchor),
        ])

        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = viewController
        window.addToMainSceneIfNeeded()
        window.isHidden = false
        defer { window.removeFromScene() }

        let eventGenerator = try EventGenerator(window: window)
        try eventGenerator.waitUntilHittable(timeout: 1)

        do {
            try eventGenerator.keyType("a")
            XCTFail("Expected error")
        } catch HammerError.windowIsNotKey {
            // Success
        }
    }
}
