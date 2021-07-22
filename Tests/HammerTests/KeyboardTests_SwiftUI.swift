import Hammer
import XCTest
#if canImport(SwiftUI)
import SwiftUI
#endif

final class KeyboardTests_SwiftUI: XCTestCase {
    func testTypeOnTextField() throws {
        guard #available(iOS 13.0, *) else {
            throw XCTSkip("SwiftUI tests require iOS 13 or later")
        }

        var text = ""
        let textBinding = Binding<String>(get: { text }, set: { text = $0 })
        let view = TextField("TextField", text: textBinding)
            .autocapitalization(.none)
            .disableAutocorrection(true)
            .frame(width: 300)

        let eventGenerator = try EventGenerator(view: view)
        try eventGenerator.waitUntilHittable(timeout: 1)

        try eventGenerator.fingerTap()
        try eventGenerator.wait(0.5)

        XCTAssertEqual(text, "")
        try eventGenerator.keyType("abc")
        XCTAssertEqual(text, "abc")
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
//
//    func testEnsureKeyWindowError() throws {
//        let view = UITextField()
//        view.disablePredictiveBar()
//        view.autocapitalizationType = .none
//        view.widthAnchor.constraint(equalToConstant: 300).isActive = true
//        let eventGenerator = try EventGenerator(view: view)
//        try eventGenerator.waitUntilHittable(timeout: 1)
//
//        do {
//            try eventGenerator.keyType("a")
//            XCTFail("Expected error")
//        } catch HammerError.windowIsNotKey {
//            // Success
//        }
//    }
}
