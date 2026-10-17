import Hammer
import SwiftUI
import UIKit
import XCTest

@MainActor
final class SwiftUITests: XCTestCase {
    func testButtonTap() async throws {
        let model = TestModel()
        let eventGenerator = try await EventGenerator(view: TestView(model: model))
        try await eventGenerator.waitUntilHittable("button")

        try await eventGenerator.fingerTap(at: "button")
        try await eventGenerator.fingerTap(at: "button")
        XCTAssertEqual(model.tapCount, 2)
    }

    func testToggle() async throws {
        let model = TestModel()
        let eventGenerator = try await EventGenerator(view: TestView(model: model))

        try await eventGenerator.fingerTap(at: "toggle")
        try await eventGenerator.waitUntil(model.isOn)
    }

    func testTypeOnTextField() async throws {
        let model = TestModel()
        let eventGenerator = try await EventGenerator(view: TestView(model: model))

        try await eventGenerator.fingerTap(at: "field")
        try await eventGenerator.keyType("abc")
        try await eventGenerator.waitUntil(model.text == "abc")
    }

    func testScrolledOutElementIsNotVisible() async throws {
        let eventGenerator = try await EventGenerator(view: TestView(model: TestModel()))

        XCTAssertTrue(eventGenerator.viewExists("row-25"))
        XCTAssertTrue(eventGenerator.viewIsVisible("row-0"))
        XCTAssertFalse(eventGenerator.viewIsVisible("row-25"))

        do {
            try await eventGenerator.fingerTap(at: "row-25")
            XCTFail("Tapping a scrolled out element should throw")
        } catch HammerError.elementIsNotVisible(let identifier) {
            XCTAssertEqual(identifier, "row-25")
        }

        try await eventGenerator.fingerDrag(from: "row-3", to: "row-0", duration: 0.3)
        try await eventGenerator.waitUntilVisible("row-6")
        XCTAssertFalse(eventGenerator.viewIsVisible("row-0"))
    }

    func testSynchronousButtonTap() throws {
        let model = TestModel()
        let eventGenerator = try EventGenerator(view: TestView(model: model))
        try eventGenerator.waitUntilHittable("button")

        try eventGenerator.fingerTap(at: "button")
        XCTAssertEqual(model.tapCount, 1)
    }
}

@MainActor
@Observable
private final class TestModel {
    var tapCount = 0
    var isOn = false
    var text = ""
}

private struct TestView: View {
    @Bindable var model: TestModel

    var body: some View {
        VStack {
            Button("Tap") { self.model.tapCount += 1 }
                .accessibilityIdentifier("button")
            Toggle("Toggle", isOn: self.$model.isOn)
                .accessibilityIdentifier("toggle")
            TextField("Field", text: self.$model.text)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .accessibilityIdentifier("field")
            ScrollView {
                VStack {
                    ForEach(0..<30) { index in
                        Text("Row \(index)")
                            .accessibilityIdentifier("row-\(index)")
                    }
                }
            }
            .frame(height: 100)
        }
        .frame(width: 300)
    }
}
