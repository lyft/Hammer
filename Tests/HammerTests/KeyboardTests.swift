import Hammer
import UIKit
import XCTest

final class KeyboardTests: XCTestCase {
    func testTypeOnTextField() throws {
        let view = UITextField()
        view.disablePredictiveBar()
        view.autocapitalizationType = .none
        view.widthAnchor.constraint(equalToConstant: 300).isActive = true
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
        view.disablePredictiveBar()
        view.autocapitalizationType = .none
        view.widthAnchor.constraint(equalToConstant: 300).isActive = true
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
        view.disablePredictiveBar()
        view.widthAnchor.constraint(equalToConstant: 300).isActive = true
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
        view.disablePredictiveBar()
        view.widthAnchor.constraint(equalToConstant: 300).isActive = true
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
        view.disablePredictiveBar()
        view.widthAnchor.constraint(equalToConstant: 300).isActive = true
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
        view.disablePredictiveBar()
        view.widthAnchor.constraint(equalToConstant: 300).isActive = true
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
        view.disablePredictiveBar()
        view.widthAnchor.constraint(equalToConstant: 300).isActive = true
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
        view.disablePredictiveBar()
        view.widthAnchor.constraint(equalToConstant: 300).isActive = true
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
        view.disablePredictiveBar()
        view.widthAnchor.constraint(equalToConstant: 300).isActive = true
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
        view.disablePredictiveBar()
        view.autocapitalizationType = .none
        view.widthAnchor.constraint(equalToConstant: 300).isActive = true
        let eventGenerator = try EventGenerator(view: view)
        try eventGenerator.waitUntilHittable(timeout: 1)

        do {
            try eventGenerator.keyType("a")
            XCTFail("Expected error")
        } catch HammerError.windowIsNotKey {
            // Success
        }
    }
}
