import Hammer
import UIKit
import XCTest
#if canImport(SwiftUI)
import SwiftUI
#endif

final class AccessibilityIdentifierTests: XCTestCase {
    func testButtonSearch() throws {
        let button = UIButton().size(width: 100, height: 100)
        button.accessibilityIdentifier = "my_button"
        button.backgroundColor = .green

        let wrapperView = UIStackView(arrangedSubviews: [button])

        let eventGenerator = try EventGenerator(view: wrapperView)
        try eventGenerator.waitUntilVisible(timeout: 5)
        let match = try eventGenerator.viewWithIdentifier("my_button")
        XCTAssertEqual(button, match)
    }

    func testButtonSearch_SwiftUI() throws {
        guard #available(iOS 13.0, *) else {
            throw XCTSkip("SwiftUI tests require iOS 13 or later")
        }

        let view = HStack {
            Button("Button", action: {})
                .accessibility(identifier: "my_button")
                .background(Color.green)
        }

        let eventGenerator = try EventGenerator(view: view)
        try eventGenerator.wait(5)
        let match = try eventGenerator.viewWithIdentifier("my_button")
        print(match)
    }
}
