import Foundation
import Hammer
import HammerAgentCore

private let kDefaultTimeout: TimeInterval = 10

struct WaitForCommand: AgentCommand {
    enum Condition: String, Decodable {
        case exists
        case visible
        case hittable
        case gone
    }

    struct Arguments: Decodable {
        private enum CodingKeys: String, CodingKey {
            case condition
            case timeout
        }

        let target: Target
        let condition: Condition
        let timeout: TimeInterval

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.target = try Target(from: decoder)
            self.condition = try container.decodeIfPresent(Condition.self, forKey: .condition) ?? .hittable
            self.timeout = try container.decodeIfPresent(TimeInterval.self, forKey: .timeout)
                ?? kDefaultTimeout
        }
    }

    let descriptor = BuiltinCommands.waitFor

    func run(_ arguments: Arguments, in context: AgentContext) async throws -> NoOutput {
        let query = try arguments.target.requiredQuery()
        let eventGenerator = try await context.eventGenerator()
        switch arguments.condition {
        case .exists:
            try await eventGenerator.waitUntilExists(query, timeout: arguments.timeout)
        case .visible:
            try await eventGenerator.waitUntilVisible(query, timeout: arguments.timeout)
        case .hittable:
            try await eventGenerator.waitUntilHittable(query, timeout: arguments.timeout)
        case .gone:
            try await eventGenerator.waitUntil(!eventGenerator.elementExists(query),
                                               timeout: arguments.timeout)
        }

        return NoOutput()
    }
}

struct WaitForIdleCommand: AgentCommand {
    struct Arguments: Decodable {
        var timeout: TimeInterval?
    }

    let descriptor = BuiltinCommands.waitForIdle

    func run(_ arguments: Arguments, in context: AgentContext) async throws -> NoOutput {
        try await context.eventGenerator()
            .waitUntilAnimationsAreFinished(timeout: arguments.timeout ?? kDefaultTimeout)
        return NoOutput()
    }
}
