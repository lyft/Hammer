@testable import Hammer
import UIKit
import XCTest

@MainActor
final class KeyboardTests: XCTestCase {
    func testTypeOnTextField() async throws {
        let view = UITextField()
        view.setSize(width: 300)
        view.disableTextSuggestions()
        view.autocapitalizationType = .none

        let eventGenerator = try await EventGenerator(view: view)
        try await eventGenerator.waitUntilHittable(timeout: 1)

        try await eventGenerator.fingerTap()
        XCTAssertTrue(view.isFirstResponder)

        XCTAssertEqual(view.text, "")
        try await eventGenerator.keyType("abc")
        XCTAssertEqual(view.text, "abc")
    }

    func testTypeOnAutocapitalizedTextField() async throws {
        let view = UITextField()
        view.setSize(width: 300)
        view.disableTextSuggestions()
        view.autocapitalizationType = .sentences

        let eventGenerator = try await EventGenerator(view: view)
        try await eventGenerator.waitUntilHittable(timeout: 1)

        try await eventGenerator.fingerTap()
        XCTAssertTrue(view.isFirstResponder)

        try await eventGenerator.keyType("be")
        XCTAssertEqual(view.text, "Be")
    }

    func testKeyOnTextField() async throws {
        let view = UITextField()
        view.setSize(width: 300)
        view.disableTextSuggestions()
        view.autocapitalizationType = .none

        let eventGenerator = try await EventGenerator(view: view)
        try await eventGenerator.waitUntilHittable(timeout: 1)

        try await eventGenerator.fingerTap()
        XCTAssertTrue(view.isFirstResponder)

        XCTAssertEqual(view.text, "")
        try await eventGenerator.keyDown("a")
        try await eventGenerator.keyUp("a")
        XCTAssertEqual(view.text, "a")
    }

    func testUppercaseCharacters() async throws {
        let keys = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

        let view = UITextField()
        view.setSize(width: 300)
        view.disableTextSuggestions()

        let eventGenerator = try await EventGenerator(view: view)
        try await eventGenerator.waitUntilHittable(timeout: 1)

        try await eventGenerator.fingerTap()
        XCTAssertTrue(view.isFirstResponder)

        XCTAssertEqual(view.text, "")
        try await eventGenerator.keyType(keys)
        XCTAssertEqual(view.text, keys)
    }

    func testLowercaseCharacters() async throws {
        let keys = "abcdefghijklmnopqrstuvwxyz"

        let view = UITextField()
        view.setSize(width: 300)
        view.disableTextSuggestions()
        view.autocapitalizationType = .none

        let eventGenerator = try await EventGenerator(view: view)
        try await eventGenerator.waitUntilHittable(timeout: 1)

        try await eventGenerator.fingerTap()
        XCTAssertTrue(view.isFirstResponder)

        XCTAssertEqual(view.text, "")
        try await eventGenerator.keyType(keys)
        XCTAssertEqual(view.text, keys)
    }

    func testNumberCharacters() async throws {
        let keys = "0123456789"

        let view = UITextField()
        view.setSize(width: 300)
        view.disableTextSuggestions()

        let eventGenerator = try await EventGenerator(view: view)
        try await eventGenerator.waitUntilHittable(timeout: 1)

        try await eventGenerator.fingerTap()
        XCTAssertTrue(view.isFirstResponder)

        XCTAssertEqual(view.text, "")
        try await eventGenerator.keyType(keys)
        XCTAssertEqual(view.text, keys)
    }

    func testSymbolCharacters() async throws {
        let keys = "-=,./;'[]\\"

        let view = UITextField()
        view.setSize(width: 300)
        view.disableTextSuggestions()

        let eventGenerator = try await EventGenerator(view: view)
        try await eventGenerator.waitUntilHittable(timeout: 1)

        try await eventGenerator.fingerTap()
        XCTAssertTrue(view.isFirstResponder)

        XCTAssertEqual(view.text, "")
        try await eventGenerator.keyType(keys)
        XCTAssertEqual(view.text, keys)
    }

    func testShiftCharacters() async throws {
        let keys = "!@#$%^&*()_+{}|:\"<>?~"

        let view = UITextField()
        view.setSize(width: 300)
        view.disableTextSuggestions()

        let eventGenerator = try await EventGenerator(view: view)
        try await eventGenerator.waitUntilHittable(timeout: 1)

        try await eventGenerator.fingerTap()
        XCTAssertTrue(view.isFirstResponder)

        XCTAssertEqual(view.text, "")
        try await eventGenerator.keyType(keys)
        XCTAssertEqual(view.text, keys)
    }

    func testSpaceCharacter() async throws {
        let keys = "a a"

        let view = UITextField()
        view.setSize(width: 300)
        view.disableTextSuggestions()
        view.autocapitalizationType = .none

        let eventGenerator = try await EventGenerator(view: view)
        try await eventGenerator.waitUntilHittable(timeout: 1)

        try await eventGenerator.fingerTap()
        XCTAssertTrue(view.isFirstResponder)

        XCTAssertEqual(view.text, "")
        try await eventGenerator.keyType(keys)
        XCTAssertEqual(view.text, keys)
    }

    func testNewlineCharacters() async throws {
        let keys = "a\na\ra"
        let result = "a\na\na"

        let view = UITextView()
        view.setSize(width: 300, height: 300)
        view.disableTextSuggestions()
        view.autocapitalizationType = .none

        let eventGenerator = try await EventGenerator(view: view)
        try await eventGenerator.waitUntilHittable(timeout: 1)

        try await eventGenerator.fingerTap()
        XCTAssertTrue(view.isFirstResponder)

        XCTAssertEqual(view.text, "")
        try await eventGenerator.keyType(keys)
        XCTAssertEqual(view.text, result)
    }

    func testEnsureKeyWindowError() async throws {
        let view = UITextField()
        view.setSize(width: 300)
        view.disableTextSuggestions()
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

        let eventGenerator = try await EventGenerator(window: window)
        try await eventGenerator.waitUntilHittable(timeout: 1)

        do {
            try await eventGenerator.keyType("a")
            XCTFail("Expected error")
        } catch HammerError.windowIsNotKey {
            // Success
        }
    }
}
