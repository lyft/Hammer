import Hammer
import HammerAgent
import UIKit
import XCTest

@MainActor
final class AgentTests: XCTestCase {
    private var agent: HammerAgent!
    private var hostEventGenerator: EventGenerator?

    override func setUp() async throws {
        try await super.setUp()
        self.agent = HammerAgent(port: 0)
        try await self.agent.start()
    }

    override func tearDown() async throws {
        self.agent.stop()
        try await self.hostEventGenerator?.finish()
        self.hostEventGenerator = nil
        try await super.tearDown()
    }

    func testListsBuiltinCommands() async throws {
        let (data, status) = try await self.agent.request("GET", AgentEndpoint.commandsPath)
        XCTAssertEqual(status, 200)
        XCTAssertEqual(try JSONDecoder().decode([CommandDescriptor].self, from: data), BuiltinCommands.all)
    }

    func testTapButtonWithIdentifier() async throws {
        let button = self.button(title: "Sign In", identifier: "sign_in")
        var tapCount = 0
        button.addHandler(forEvent: .primaryActionTriggered) { tapCount += 1 }
        try await self.present(button)

        let (_, status) = try await self.agent.run("tap", ["identifier": "sign_in", "count": 2])
        XCTAssertEqual(status, 200)
        XCTAssertEqual(tapCount, 2)
    }

    func testTapButtonWithRefFromDescribe() async throws {
        let button = self.button(title: "Sign In", identifier: "sign_in")
        var tapCount = 0
        button.addHandler(forEvent: .primaryActionTriggered) { tapCount += 1 }
        try await self.present(button)

        let (data, _) = try await self.agent.run("describe")
        let nodes = try JSONDecoder().decode([DescribedNode].self, from: data)
        let ref = try XCTUnwrap(nodes.flatMap(\.flattened).first { $0.identifier == "sign_in" }?.ref)

        let (_, status) = try await self.agent.run("tap", ["ref": .string(ref)])
        XCTAssertEqual(status, 200)
        XCTAssertEqual(tapCount, 1)

        let (secondData, _) = try await self.agent.run("describe")
        let secondNodes = try JSONDecoder().decode([DescribedNode].self, from: secondData)
        XCTAssertEqual(secondNodes.flatMap(\.flattened).first { $0.identifier == "sign_in" }?.ref, ref)
    }

    func testRejectsUnknownRef() async throws {
        try await self.present(self.button(title: "Sign In", identifier: "sign_in"))

        let (_, status) = try await self.agent.run("tap", ["ref": "e999999"])
        XCTAssertEqual(status, 400)
    }

    func testParameterTypesRoundTripAndUnknownTypesDecodeAsJSON() throws {
        let types: [CommandDescriptor.ParameterType] = [
            .string, .integer, .number, .boolean, .stringList, .choice(["a", "b"]), .json,
        ]
        let decoded = try JSONDecoder().decode([CommandDescriptor.ParameterType].self,
                                               from: JSONEncoder().encode(types))
        XCTAssertEqual(decoded, types)

        let unknown = try JSONDecoder().decode(CommandDescriptor.ParameterType.self,
                                               from: Data(#"{"type":"color"}"#.utf8))
        XCTAssertEqual(unknown, .json)
    }

    func testDescribeIncludesAccessibilityInformation() async throws {
        try await self.present(self.button(title: "Sign In", identifier: "sign_in"))

        let (data, status) = try await self.agent.run("describe")
        XCTAssertEqual(status, 200)
        let output = try XCTUnwrap(String(bytes: data, encoding: .utf8))
        XCTAssertTrue(output.contains(#""identifier":"sign_in""#), output)
        XCTAssertTrue(output.contains(#""label":"Sign In""#), output)
        XCTAssertTrue(output.contains(#""traits":["button"]"#), output)
    }

    func testTypeTextTapsFieldFirst() async throws {
        let textField = UITextField()
        textField.accessibilityIdentifier = "name"
        textField.disableTextSuggestions()
        textField.setSize(width: 200, height: 40)
        try await self.present(textField)

        let (_, status) = try await self.agent.run("type_text", ["identifier": "name", "text": "Hammer"])
        XCTAssertEqual(status, 200)
        XCTAssertEqual(textField.text, "Hammer")
    }

    func testScreenshotIsPNG() async throws {
        try await self.present(self.button(title: "Sign In", identifier: "sign_in"))

        let (data, status) = try await self.agent.run("screenshot")
        XCTAssertEqual(status, 200)
        let image = try JSONDecoder().decode(AgentImage.self, from: data)
        XCTAssertEqual(image.mimeType, "image/png")
        XCTAssertNotNil(UIImage(data: image.data))
    }

    func testRejectsUnknownArgument() async throws {
        try await self.present(self.button(title: "Sign In", identifier: "sign_in"))

        let (data, status) = try await self.agent.run("tap", ["identifer": "sign_in"])
        XCTAssertEqual(status, 400)
        let body = try JSONDecoder().decode(AgentErrorBody.self, from: data)
        XCTAssertEqual(body.error, #"Unknown argument "identifer" for tap, did you mean "identifier"?"#)
        XCTAssertTrue(body.hint?.contains("identifier: a string") == true, body.hint ?? "")
    }

    func testRejectsInvalidArgumentValues() async throws {
        try await self.present(self.button(title: "Sign In", identifier: "sign_in"))

        let (data, status) = try await self.agent.run("swipe", ["direction": "upward"])
        XCTAssertEqual(status, 400)
        XCTAssertEqual(try JSONDecoder().decode(AgentErrorBody.self, from: data).error,
                       #"Invalid value "upward" for "direction", expected one of up, down, left, right"#)
    }

    func testReportsCommandErrors() async throws {
        try await self.present(self.button(title: "Sign In", identifier: "sign_in"))

        let (data, status) = try await self.agent.run("tap", ["identifier": "missing"])
        XCTAssertEqual(status, 500)
        let body = try JSONDecoder().decode(AgentErrorBody.self, from: data)
        XCTAssertTrue(body.error.contains("missing"), body.error)
        XCTAssertTrue(body.hint?.contains("describe") == true, body.hint ?? "")
    }

    func testSuggestsCommandForTypo() async throws {
        let (data, status) = try await self.agent.request("POST", AgentEndpoint.commandPath("tapp"))
        XCTAssertEqual(status, 404)
        XCTAssertEqual(try JSONDecoder().decode(AgentErrorBody.self, from: data).error,
                       #"Unknown command "tapp", did you mean tap?"#)
    }

    func testBuiltinExamplesAreValid() throws {
        for command in BuiltinCommands.all {
            for example in command.examples {
                XCTAssertNoThrow(try command.validate(example.arguments),
                                 "\(command.name): \(example.summary)")
            }
        }
    }

    func testRunsRegisteredCommand() async throws {
        struct GreetCommand: AgentCommand {
            struct Arguments: Decodable {
                let name: String
            }

            let descriptor = CommandDescriptor(name: "greet", summary: "Greets someone.",
                                               parameters: [.init("name", .string, "Who.", isRequired: true)])

            func run(_ arguments: Arguments, in context: AgentContext) async throws -> [String: String] {
                return ["greeting": "Hello \(arguments.name)"]
            }
        }

        self.agent.register(GreetCommand())
        XCTAssertEqual(self.agent.commands.last?.name, "greet")

        let (data, status) = try await self.agent.run("greet", ["name": "Hammer"])
        XCTAssertEqual(status, 200)
        XCTAssertEqual(try JSONDecoder().decode([String: String].self, from: data),
                       ["greeting": "Hello Hammer"])
    }

    func testTapTogglesSwitch() async throws {
        let toggle = UISwitch()
        toggle.accessibilityIdentifier = "wifi"
        try await self.present(toggle)

        let (_, status) = try await self.agent.run("tap", ["identifier": "wifi"])
        XCTAssertEqual(status, 200)
        XCTAssertTrue(toggle.isOn)
    }

    func testLongPress() async throws {
        let view = UIView()
        view.accessibilityIdentifier = "pressable"
        view.setSize(width: 200, height: 200)
        let recognizer = UILongPressGestureRecognizer()
        view.addGestureRecognizer(recognizer)
        var beganCount = 0
        recognizer.addHandler(forState: .began) { beganCount += 1 }
        try await self.present(view)

        let (_, status) = try await self.agent.run("long_press", ["identifier": "pressable", "duration": 1])
        XCTAssertEqual(status, 200)
        XCTAssertEqual(beganCount, 1)
    }

    func testSwipeScrollsContent() async throws {
        let scrollView = PatternScrollView()
        scrollView.accessibilityIdentifier = "scroll"
        scrollView.setSize(width: 300, height: 300)
        try await self.present(scrollView)

        let (_, status) = try await self.agent.run("swipe", ["identifier": "scroll", "direction": "up"])
        XCTAssertEqual(status, 200)
        XCTAssertGreaterThan(scrollView.contentOffset.y, 0)
        XCTAssertEqual(scrollView.contentOffset.x, 0)
    }

    func testEdgeSwipeNavigatesBack() async throws {
        let navigationController = UINavigationController()
        navigationController.viewControllers = [UIViewController(), UIViewController()]
        let hostEventGenerator = try await EventGenerator(viewController: navigationController)
        self.hostEventGenerator = hostEventGenerator

        let (_, status) = try await self.agent.run("edge_swipe", ["direction": "right"])
        XCTAssertEqual(status, 200)
        try await hostEventGenerator.waitUntil(navigationController.viewControllers.count == 1, timeout: 1)
    }

    func testDragMovesFingerBetweenTargets() async throws {
        let view = TouchTestView()
        view.accessibilityIdentifier = "canvas"
        view.setSize(width: 300, height: 300)
        try await self.present(view)

        let center = view.convert(CGPoint(x: 150, y: 150), to: nil)
        let (_, status) = try await self.agent.run("drag", [
            "identifier": "canvas", "to_x": .number(center.x + 100), "to_y": .number(center.y),
        ])
        XCTAssertEqual(status, 200)
        let touch = try XCTUnwrap(view.endedTouches.first)
        XCTAssertEqual(touch.location(in: view), CGPoint(x: 250, y: 150), accuracy: 1)
    }

    func testPressKeyDeletesText() async throws {
        let textField = UITextField()
        textField.accessibilityIdentifier = "name"
        textField.disableTextSuggestions()
        textField.autocapitalizationType = .none
        textField.setSize(width: 200, height: 40)
        try await self.present(textField)

        _ = try await self.agent.run("type_text", ["identifier": "name", "text": "ab"])
        let (_, status) = try await self.agent.run("press_key", ["key": "deleteOrBackspace"])
        XCTAssertEqual(status, 200)
        XCTAssertEqual(textField.text, "a")
    }

    // MARK: - Helpers

    private struct DescribedNode: Decodable {
        let ref: String
        let identifier: String?
        let children: [DescribedNode]?

        var flattened: [DescribedNode] {
            return [self] + (self.children ?? []).flatMap(\.flattened)
        }
    }

    private func button(title: String, identifier: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.accessibilityIdentifier = identifier
        button.setSize(width: 200, height: 50)
        return button
    }

    private func present(_ view: UIView) async throws {
        self.hostEventGenerator = try await EventGenerator(view: view)
    }
}
