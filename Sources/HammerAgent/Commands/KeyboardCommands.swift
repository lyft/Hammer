import Foundation
import Hammer
import HammerAgentCore

struct TypeTextCommand: AgentCommand {
    struct Arguments: Decodable {
        private enum CodingKeys: String, CodingKey {
            case text
        }

        let text: String
        let target: Target

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.text = try container.decode(String.self, forKey: .text)
            self.target = try Target(from: decoder)
        }
    }

    let descriptor = BuiltinCommands.typeText

    func run(_ arguments: Arguments, in context: AgentContext) async throws -> NoOutput {
        let eventGenerator = try await context.eventGenerator()
        if let location = try arguments.target.location(in: context) {
            try await eventGenerator.fingerTap(at: location)
        }

        try await eventGenerator.keyType(arguments.text)
        return NoOutput()
    }
}

struct PressKeyCommand: AgentCommand {
    struct Arguments: Decodable {
        let key: String
    }

    let descriptor = BuiltinCommands.pressKey

    func run(_ arguments: Arguments, in context: AgentContext) async throws -> NoOutput {
        let eventGenerator = try await context.eventGenerator()
        if let key = KeyboardKey.allCases.first(where: { "\($0)" == arguments.key }) {
            try await eventGenerator.keyPress(key)
        } else if arguments.key.count == 1, let character = arguments.key.first {
            try await eventGenerator.keyPress(character)
        } else {
            throw AgentError.invalidArguments("Unknown key \"\(arguments.key)\"")
        }

        return NoOutput()
    }
}
