import Hammer
import HammerAgent
import UIKit
import XCTest

@MainActor
final class AgentEditingTests: XCTestCase {
    private struct Inspection: Decodable {
        struct Property: Decodable {
            let name: String
            let value: JSONValue
            let settable: Bool
        }

        struct Constraint: Decodable {
            let ref: String
            let description: String
            let firstAttribute: String
        }

        let ref: String
        let properties: [Property]
        let constraints: [Constraint]
    }

    private struct Node: Decodable {
        let ref: String
        let identifier: String?
        let hidden: Bool?
        let children: [Node]?

        var flattened: [Node] {
            return [self] + (self.children ?? []).flatMap(\.flattened)
        }
    }

    private var agent: HammerAgent!
    private var hostEventGenerator: EventGenerator?
    private var box: UIView!
    private var widthConstraint: NSLayoutConstraint!

    override func setUp() async throws {
        try await super.setUp()
        self.agent = HammerAgent(port: 0)
        try await self.agent.start()

        let container = UIView().withSize(width: 300, height: 300)
        self.box = UIView()
        self.box.accessibilityIdentifier = "box"
        self.box.backgroundColor = .white
        self.box.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(self.box)

        let hidden = UIView()
        hidden.accessibilityIdentifier = "hidden_view"
        hidden.isHidden = true
        container.addSubview(hidden)

        let other = UIView(frame: CGRect(x: 100, y: 100, width: 50, height: 60))
        other.accessibilityIdentifier = "other"
        container.addSubview(other)

        self.widthConstraint = self.box.widthAnchor.constraint(equalToConstant: 100)
        // Lower than required, so added height constraints can replace it
        let height = self.box.heightAnchor.constraint(equalToConstant: 50)
        height.priority = .defaultHigh
        NSLayoutConstraint.activate([
            self.widthConstraint,
            height,
            self.box.topAnchor.constraint(equalTo: container.topAnchor),
            self.box.leadingAnchor.constraint(equalTo: container.leadingAnchor),
        ])
        self.hostEventGenerator = try await EventGenerator(view: container)
    }

    override func tearDown() async throws {
        self.agent.stop()
        try await self.hostEventGenerator?.finish()
        self.hostEventGenerator = nil
        try await super.tearDown()
    }

    func testInspectListsPropertiesAndConstraints() async throws {
        let inspection = try await self.inspectBox()
        let alpha = try XCTUnwrap(inspection.properties.first { $0.name == "alpha" })
        XCTAssertEqual(alpha.value, 1)
        XCTAssertTrue(alpha.settable)
        XCTAssertEqual(inspection.properties.first { $0.name == "backgroundColor" }?.value, "#FFFFFF")
        XCTAssertEqual(inspection.properties.first { $0.name == "intrinsicContentSize" }?.settable, false)
        let descriptions = inspection.constraints.map(\.description)
        XCTAssertTrue(descriptions.contains("\(inspection.ref).width == 100"), "\(descriptions)")
    }

    func testHierarchyIncludesHiddenViews() async throws {
        let nodes = try await self.run("hierarchy", as: Node.self).flattened
        XCTAssertEqual(nodes.first { $0.identifier == "hidden_view" }?.hidden, true)
        XCTAssertNil(nodes.first { $0.identifier == "box" }?.hidden)

        let box = try await self.run("hierarchy", ["identifier": "box", "depth": 0], as: Node.self)
        XCTAssertNil(box.children)
    }

    func testSetPropertyAndRevert() async throws {
        try await self.setBoxProperty("backgroundColor", "#FF0000")
        try await self.setBoxProperty("alpha", 0.5)
        try await self.setBoxProperty("isHidden", true)
        XCTAssertEqual(self.box.backgroundColor, UIColor(red: 1, green: 0, blue: 0, alpha: 1))
        XCTAssertEqual(self.box.alpha, 0.5)
        XCTAssertTrue(self.box.isHidden)

        // Only the first change of a property is kept, so revert restores the original value
        try await self.setBoxProperty("alpha", 0.2)
        let reverted = try await self.run("revert", as: [String: [String]].self)
        XCTAssertEqual(reverted["reverted"]?.count, 3)
        XCTAssertEqual(self.box.backgroundColor, .white)
        XCTAssertEqual(self.box.alpha, 1)
        XCTAssertFalse(self.box.isHidden)
    }

    func testSetPropertyRejectsInvalidValuesAndUnknownProperties() async throws {
        let invalid = try await self.error("set_property", [
            "identifier": "box", "property": "alpha", "to": "red",
        ])
        XCTAssertTrue(invalid.contains("expected a number"), invalid)

        let unknown = try await self.error("set_property", [
            "identifier": "box", "property": "alpah", "to": 1,
        ])
        XCTAssertTrue(unknown.contains("did you mean alpha?"), unknown)
    }

    func testSetConstraintChangesConstantAndPriority() async throws {
        let inspection = try await self.inspectBox()
        let ref = try XCTUnwrap(inspection.constraints.first { $0.firstAttribute == "width" }?.ref)

        _ = try await self.run("set_constraint", [
            "constraint": .string(ref), "constant": 150, "priority": 750,
        ], as: JSONValue.self)
        XCTAssertEqual(self.box.frame.width, 150)
        XCTAssertEqual(self.widthConstraint.priority.rawValue, 750)
        XCTAssertTrue(self.widthConstraint.isActive)

        _ = try await self.run("revert", ["identifier": "box"], as: JSONValue.self)
        XCTAssertEqual(self.box.frame.width, 100)
        XCTAssertEqual(self.widthConstraint.priority, .required)
    }

    func testAddConstraintAndRevert() async throws {
        _ = try await self.run("add_constraint", [
            "identifier": "box", "attribute": "height", "to_identifier": "other", "multiplier": 2,
        ], as: JSONValue.self)
        XCTAssertEqual(self.box.frame.height, 120)

        _ = try await self.run("add_constraint", [
            "identifier": "box", "attribute": "height", "constant": 80, "priority": 999,
        ], as: JSONValue.self)
        XCTAssertEqual(self.box.frame.height, 120)

        _ = try await self.run("revert", as: JSONValue.self)
        XCTAssertEqual(self.box.frame.height, 50)
    }

    func testAddConstraintRejectsInvalidAttributes() async throws {
        let position = try await self.error("add_constraint", [
            "identifier": "box", "attribute": "leading", "constant": 10,
        ])
        XCTAssertTrue(position.contains("can't be set to a constant"), position)

        let mixed = try await self.error("add_constraint", [
            "identifier": "box", "attribute": "leading", "to_identifier": "other", "to_attribute": "left",
        ])
        XCTAssertTrue(mixed.contains("can't be related to left"), mixed)
    }

    func testScreenshotOfView() async throws {
        let screenshot = try await self.run("screenshot", ["identifier": "box", "scale": 2],
                                            as: AgentImage.self)
        let image = try XCTUnwrap(UIImage(data: screenshot.data))
        XCTAssertEqual(image.size.width * image.scale, 200)
        XCTAssertEqual(image.size.height * image.scale, 100)
    }

    private func inspectBox() async throws -> Inspection {
        return try await self.run("inspect", ["identifier": "box"], as: Inspection.self)
    }

    private func setBoxProperty(_ property: String, _ value: JSONValue) async throws {
        _ = try await self.run("set_property", [
            "identifier": "box", "property": .string(property), "to": value,
        ], as: JSONValue.self)
    }

    private func run<Output: Decodable>(_ command: String, _ arguments: [String: JSONValue] = [:],
                                        as type: Output.Type) async throws -> Output
    {
        let (data, status) = try await self.agent.run(command, arguments)
        XCTAssertEqual(status, 200, String(bytes: data, encoding: .utf8) ?? "")
        return try JSONDecoder().decode(type, from: data)
    }

    /// Runs a command that should fail because of its arguments, and returns the error message.
    private func error(_ command: String, _ arguments: [String: JSONValue]) async throws -> String {
        let (data, status) = try await self.agent.run(command, arguments)
        XCTAssertEqual(status, 400)
        return try JSONDecoder().decode(AgentErrorBody.self, from: data).error
    }
}
