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

        /// The state the element did not reach, to explain a timeout.
        var expectedState: String {
            return self == .exists ? "found" : self.rawValue
        }
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
        let deadline = Date().addingTimeInterval(arguments.timeout)
        var isMet = await Self.isMet(arguments.condition, for: query, in: eventGenerator)
        while !isMet && Date() < deadline {
            try await eventGenerator.wait(kPollInterval)
            isMet = await Self.isMet(arguments.condition, for: query, in: eventGenerator)
        }

        if !isMet {
            let exists = await Self.isMet(.exists, for: query, in: eventGenerator)
            throw AgentError.failed("""
                The element with \(query) was not \(arguments.condition.expectedState) after \
                \(arguments.timeout) seconds, and it \(exists ? "exists" : "does not exist")
                """, hint: """
                Take a screenshot or call describe to see the current state, then wait for a different \
                element or pass a longer timeout
                """, code: .timedOut)
        }

        return NoOutput()
    }

    /// Checks the condition for the views and accessibility elements, then for the elements of web pages.
    private static func isMet(_ condition: Condition, for query: AccessibilityQuery,
                              in eventGenerator: EventGenerator) async -> Bool
    {
        let isMetByViews = switch condition {
        case .exists: eventGenerator.elementExists(query)
        case .visible: eventGenerator.elementIsVisible(query)
        case .hittable: eventGenerator.elementIsHittable(query)
        case .gone: !eventGenerator.elementExists(query)
        }

        // A view that matches is enough, except for gone, which no web element may match either
        if isMetByViews != (condition == .gone) {
            return isMetByViews
        }

        let webElements = await WebContent.elements(matching: query, in: eventGenerator.window)
        return switch condition {
        case .exists: !webElements.isEmpty
        case .visible: webElements.contains(where: \.isVisible)
        case .hittable: webElements.contains(where: \.isHittable)
        case .gone: webElements.isEmpty
        }
    }
}

/// How often waits check their condition, about every frame.
private let kPollInterval: TimeInterval = 1.0 / 60

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
