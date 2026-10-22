import Foundation
import Hammer
import HammerAgentCore

struct TapCommand: AgentCommand {
    struct Arguments: Decodable {
        private enum CodingKeys: String, CodingKey {
            case count
        }

        let target: Target
        let count: Int

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.target = try Target(from: decoder)
            self.count = try container.decodeIfPresent(Int.self, forKey: .count) ?? 1
        }
    }

    let descriptor = BuiltinCommands.tap

    func run(_ arguments: Arguments, in context: AgentContext) async throws -> NoOutput {
        guard arguments.count > 0 else {
            throw AgentError.invalidArguments("Invalid count \(arguments.count), expected 1 or more",
                                              hint: "Use 1 for a tap and 2 for a double tap")
        }

        let location = try arguments.target.location(in: context)
        try await context.eventGenerator().fingerTap(at: location, numberOfTimes: arguments.count)
        return NoOutput()
    }
}

struct LongPressCommand: AgentCommand {
    struct Arguments: Decodable {
        private enum CodingKeys: String, CodingKey {
            case duration
        }

        let target: Target
        let duration: TimeInterval

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.target = try Target(from: decoder)
            self.duration = try container.decodeIfPresent(TimeInterval.self, forKey: .duration)
                ?? EventGenerator.longPressHoldDelay
        }
    }

    let descriptor = BuiltinCommands.longPress

    func run(_ arguments: Arguments, in context: AgentContext) async throws -> NoOutput {
        let location = try arguments.target.location(in: context)
        try await context.eventGenerator().fingerLongPress(at: location, duration: arguments.duration)
        return NoOutput()
    }
}

/// The arguments shared by the swipe commands.
struct SwipeArguments: Decodable {
    private enum CodingKeys: String, CodingKey {
        case direction
        case distance
        case duration
    }

    let direction: SwipeDirection
    let distance: CGFloat
    let duration: TimeInterval

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let directionName = try container.decode(String.self, forKey: .direction)
        guard let direction = SwipeDirection.allCases.first(where: { "\($0)" == directionName }) else {
            let names = SwipeDirection.allCases.map { "\($0)" }
            throw AgentError.invalidArguments("Unknown direction \"\(directionName)\"",
                                              hint: "Use one of \(names.joined(separator: ", "))")
        }

        self.direction = direction
        self.distance = try container.decodeIfPresent(CGFloat.self, forKey: .distance)
            ?? EventGenerator.swipeDistance
        self.duration = try container.decodeIfPresent(TimeInterval.self, forKey: .duration)
            ?? EventGenerator.swipeDuration
    }
}

struct SwipeCommand: AgentCommand {
    struct Arguments: Decodable {
        let target: Target
        let swipe: SwipeArguments

        init(from decoder: Decoder) throws {
            self.target = try Target(from: decoder)
            self.swipe = try SwipeArguments(from: decoder)
        }
    }

    let descriptor = BuiltinCommands.swipe

    func run(_ arguments: Arguments, in context: AgentContext) async throws -> NoOutput {
        let location = try arguments.target.location(in: context)
        let swipe = arguments.swipe
        try await context.eventGenerator().fingerSwipe(at: location, direction: swipe.direction,
                                                       distance: swipe.distance, duration: swipe.duration)
        return NoOutput()
    }
}

struct EdgeSwipeCommand: AgentCommand {
    let descriptor = BuiltinCommands.edgeSwipe

    func run(_ arguments: SwipeArguments, in context: AgentContext) async throws -> NoOutput {
        try await context.eventGenerator().fingerEdgeSwipe(direction: arguments.direction,
                                                           distance: arguments.distance,
                                                           duration: arguments.duration)
        return NoOutput()
    }
}

struct DragCommand: AgentCommand {
    struct Arguments: Decodable {
        private enum CodingKeys: String, CodingKey {
            case duration
        }

        let start: Target
        let end: Target
        let duration: TimeInterval

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.start = try Target(from: decoder)
            self.end = try Target(from: decoder, prefix: "to_")
            self.duration = try container.decodeIfPresent(TimeInterval.self, forKey: .duration) ?? 0.5
        }
    }

    let descriptor = BuiltinCommands.drag

    func run(_ arguments: Arguments, in context: AgentContext) async throws -> NoOutput {
        guard let start = try arguments.start.location(in: context),
              let end = try arguments.end.location(in: context)
        else {
            throw AgentError.invalidArguments("The drag needs where it starts and where it ends", hint: """
                Pass the start as ref, identifier, label, value, traits or x and y, and the end with the \
                same arguments prefixed with to_, such as to_ref or to_x and to_y
                """)
        }

        try await context.eventGenerator().fingerDrag(from: start, to: end, duration: arguments.duration)
        return NoOutput()
    }
}
