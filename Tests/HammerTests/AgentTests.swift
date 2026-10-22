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
        let (data, status) = try await self.request("GET", AgentEndpoint.commandsPath)
        XCTAssertEqual(status, 200)
        XCTAssertEqual(try JSONDecoder().decode([CommandDescriptor].self, from: data), BuiltinCommands.all)
    }

    func testTapButtonWithIdentifier() async throws {
        let button = self.button(title: "Sign In", identifier: "sign_in")
        var tapCount = 0
        button.addHandler(forEvent: .primaryActionTriggered) { tapCount += 1 }
        try await self.present(button)

        let (_, status) = try await self.run("tap", ["identifier": "sign_in", "count": 2])
        XCTAssertEqual(status, 200)
        XCTAssertEqual(tapCount, 2)
    }

    func testTapButtonWithRefFromDescribe() async throws {
        let button = self.button(title: "Sign In", identifier: "sign_in")
        var tapCount = 0
        button.addHandler(forEvent: .primaryActionTriggered) { tapCount += 1 }
        try await self.present(button)

        let (data, _) = try await self.run("describe")
        let nodes = try JSONDecoder().decode([DescribedNode].self, from: data)
        let ref = try XCTUnwrap(nodes.flatMap(\.flattened).first { $0.identifier == "sign_in" }?.ref)

        let (_, status) = try await self.run("tap", ["ref": .string(ref)])
        XCTAssertEqual(status, 200)
        XCTAssertEqual(tapCount, 1)

        let (secondData, _) = try await self.run("describe")
        let secondNodes = try JSONDecoder().decode([DescribedNode].self, from: secondData)
        XCTAssertEqual(secondNodes.flatMap(\.flattened).first { $0.identifier == "sign_in" }?.ref, ref)
    }

    func testRejectsUnknownRef() async throws {
        try await self.present(self.button(title: "Sign In", identifier: "sign_in"))

        let (_, status) = try await self.run("tap", ["ref": "e999999"])
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

        let (data, status) = try await self.run("describe")
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

        let (_, status) = try await self.run("type_text", ["identifier": "name", "text": "Hammer"])
        XCTAssertEqual(status, 200)
        XCTAssertEqual(textField.text, "Hammer")
    }

    func testScreenshotIsPNG() async throws {
        try await self.present(self.button(title: "Sign In", identifier: "sign_in"))

        let (data, status) = try await self.run("screenshot")
        XCTAssertEqual(status, 200)
        let image = try JSONDecoder().decode(AgentImage.self, from: data)
        XCTAssertEqual(image.mimeType, "image/png")
        XCTAssertNotNil(UIImage(data: image.data))
    }

    func testRejectsUnknownArgument() async throws {
        try await self.present(self.button(title: "Sign In", identifier: "sign_in"))

        let (data, status) = try await self.run("tap", ["identifer": "sign_in"])
        XCTAssertEqual(status, 400)
        XCTAssertEqual(try JSONDecoder().decode(AgentErrorBody.self, from: data).error,
                       #"Unknown argument "identifer""#)
    }

    func testReportsCommandErrors() async throws {
        try await self.present(self.button(title: "Sign In", identifier: "sign_in"))

        let (data, status) = try await self.run("tap", ["identifier": "missing"])
        XCTAssertEqual(status, 500)
        XCTAssertTrue(try JSONDecoder().decode(AgentErrorBody.self, from: data).error.contains("missing"))
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

        let (data, status) = try await self.run("greet", ["name": "Hammer"])
        XCTAssertEqual(status, 200)
        XCTAssertEqual(try JSONDecoder().decode([String: String].self, from: data),
                       ["greeting": "Hello Hammer"])
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

    private func run(_ command: String, _ arguments: [String: JSONValue] = [:]) async throws -> (Data, Int) {
        return try await self.request("POST", AgentEndpoint.commandPath(command),
                                      body: try JSONEncoder().encode(arguments))
    }

    private func request(_ method: String, _ path: String, body: Data? = nil) async throws -> (Data, Int) {
        let port = try XCTUnwrap(self.agent.port)
        var request = URLRequest(url: try XCTUnwrap(URL(string: "http://127.0.0.1:\(port)\(path)")))
        request.httpMethod = method
        request.httpBody = body
        let (data, response) = try await URLSession.shared.data(for: request)
        return (data, try XCTUnwrap(response as? HTTPURLResponse).statusCode)
    }
}
