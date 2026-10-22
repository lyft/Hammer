import Hammer
import SwiftUI
import UIKit
import XCTest

@MainActor
final class AccessibilityQueryTests: XCTestCase {
    func testTapSwiftUIButtonWithLabel() async throws {
        var tapCount = 0
        let eventGenerator = try await EventGenerator(view: VStack {
            Text("Sign In")
            Button("Sign In") { tapCount += 1 }
        })

        try await eventGenerator.waitUntilHittable(.label("Sign In"))
        try await eventGenerator.fingerTap(at: .label("Sign In"))
        try await eventGenerator.waitUntil(tapCount == 1)
    }

    func testTapSwiftUIToggleWithLabel() async throws {
        var isOn = false
        let eventGenerator = try await EventGenerator(view: VStack {
            Toggle("Wi-Fi", isOn: Binding(get: { isOn }, set: { isOn = $0 }))
        })

        try await eventGenerator.fingerTap(at: .label("Wi-Fi"))
        try await eventGenerator.waitUntil(isOn)
    }

    func testTapTableViewCellSwitchWithLabel() async throws {
        let toggle = UISwitch()
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.textLabel?.text = "Wi-Fi"
        cell.accessoryView = toggle
        let dataSource = SingleCellDataSource(cell: cell)
        let tableView = UITableView()
        tableView.dataSource = dataSource
        tableView.setSize(width: 300, height: 300)

        let eventGenerator = try await EventGenerator(view: tableView)
        try await eventGenerator.waitUntilHittable(.label("Wi-Fi"))
        try await eventGenerator.fingerTap(at: .label("Wi-Fi"))
        XCTAssertTrue(toggle.isOn)
    }

    func testTapButtonWithTitleLabel() async throws {
        let button = UIButton(type: .system)
        button.setTitle("Sign In", for: .normal)
        button.setSize(width: 200, height: 50)

        let expectation = XCTestExpectation(description: "Button Tapped")
        button.addHandler(forEvent: .primaryActionTriggered, action: expectation.fulfill)

        let eventGenerator = try await EventGenerator(view: button)
        try await eventGenerator.fingerTap(at: .label("Sign In"))
        await self.fulfillment(of: [expectation], timeout: 1)
    }

    func testPrefersActionableElement() async throws {
        let label = UILabel()
        label.text = "Continue"
        let button = UIButton(type: .system)
        button.setTitle("Continue", for: .normal)

        let expectation = XCTestExpectation(description: "Button Tapped")
        button.addHandler(forEvent: .primaryActionTriggered, action: expectation.fulfill)

        let eventGenerator = try await EventGenerator(view: self.stack(label, button))
        try await eventGenerator.fingerTap(at: .label("Continue"))
        await self.fulfillment(of: [expectation], timeout: 1)
    }

    func testPrefersVisibleElement() async throws {
        let hiddenButton = UIButton(type: .system)
        hiddenButton.setTitle("Hidden", for: .normal)
        hiddenButton.accessibilityIdentifier = "my_button"
        hiddenButton.isHidden = true
        let visibleButton = UIButton(type: .system)
        visibleButton.setTitle("Visible", for: .normal)
        visibleButton.accessibilityIdentifier = "my_button"

        let eventGenerator = try await EventGenerator(view: self.stack(hiddenButton, visibleButton))
        XCTAssertTrue(try eventGenerator.viewWithIdentifier("my_button") === visibleButton)
    }

    func testMultipleMatches() async throws {
        let firstButton = UIButton(type: .system)
        firstButton.setTitle("First", for: .normal)
        firstButton.accessibilityIdentifier = "my_button"
        let secondButton = UIButton(type: .system)
        secondButton.setTitle("Second", for: .normal)
        secondButton.accessibilityIdentifier = "my_button"

        let eventGenerator = try await EventGenerator(view: self.stack(firstButton, secondButton))
        do {
            try await eventGenerator.fingerTap(at: "my_button")
            XCTFail("Tapping an identifier with multiple matches should throw")
        } catch HammerError.multipleElementsFound(let query, let count) {
            XCTAssertEqual(query.identifier, "my_button")
            XCTAssertEqual(count, 2)
        }

        eventGenerator.settings.throwOnMultipleMatches = false
        XCTAssertTrue(try eventGenerator.viewWithIdentifier("my_button") === firstButton)
    }

    func testTraits() async throws {
        let label = UILabel()
        label.text = "Title"
        label.accessibilityIdentifier = "title"

        let eventGenerator = try await EventGenerator(view: label)
        XCTAssertTrue(eventGenerator.elementIsVisible(.identifier("title", traits: .staticText)))
        XCTAssertFalse(eventGenerator.elementExists(.identifier("title", traits: .button)))
    }

    func testValue() async throws {
        let eventGenerator = try await EventGenerator(view: VStack {
            Toggle("Wi-Fi", isOn: .constant(true))
        })

        XCTAssertTrue(eventGenerator.elementExists(AccessibilityQuery(label: "Wi-Fi", value: "1")))
        XCTAssertFalse(eventGenerator.elementExists(AccessibilityQuery(label: "Wi-Fi", value: "0")))
    }

    private func stack(_ views: UIView...) -> UIStackView {
        let stackView = UIStackView(arrangedSubviews: views)
        stackView.axis = .vertical
        stackView.spacing = 20
        return stackView
    }
}

private final class SingleCellDataSource: NSObject, UITableViewDataSource {
    let cell: UITableViewCell

    init(cell: UITableViewCell) {
        self.cell = cell
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return self.cell
    }
}
