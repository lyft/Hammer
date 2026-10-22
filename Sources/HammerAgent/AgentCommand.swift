import Foundation
import Hammer
import HammerAgentCore
import UIKit

/// A command the agent runs for its clients, such as a tap or an app specific action like signing in.
public protocol AgentCommand: Sendable {
    /// The arguments, decoded from the JSON object the client sends.
    associatedtype Arguments: Decodable

    /// The output, encoded as the JSON the client receives.
    associatedtype Output: Encodable

    /// Describes the command to clients. The parameters must match the keys `Arguments` decodes.
    var descriptor: CommandDescriptor { get }

    /// Runs the command.
    ///
    /// - parameter arguments: The arguments from the client.
    /// - parameter context:   The state of this run, such as the event generator for the key window.
    ///
    /// - throws: An error to report to the client.
    ///
    /// - returns: The output for the client.
    @MainActor
    func run(_ arguments: Arguments, in context: AgentContext) async throws -> Output
}

/// The arguments of a command that takes none.
public struct NoArguments: Decodable, Sendable {}

/// The output of a command that only reports it succeeded.
public struct NoOutput: Encodable, Sendable {
    public init() {}
}

/// The state of one command run.
@MainActor
public final class AgentContext {
    private var generator: EventGenerator?

    init() {}

    /// The event generator for the key window, created on first use and finished after the command runs.
    ///
    /// - throws: An error if there is no key window or it is not ready for interaction.
    public func eventGenerator() async throws -> EventGenerator {
        if let generator = self.generator {
            return generator
        }

        let generator = try await EventGenerator(window: try Self.keyWindow())
        self.generator = generator
        return generator
    }

    func finish() async throws {
        try await self.generator?.finish()
    }

    private static func keyWindow() throws -> UIWindow {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .keyWindow
        guard let window else {
            throw AgentError.noKeyWindow
        }

        return window
    }
}

/// An error a command reports to the client.
public enum AgentError: Error, CustomStringConvertible {
    /// The arguments do not match the command's parameters.
    case invalidArguments(String)

    /// The app has no foreground key window to send events to.
    case noKeyWindow

    public var description: String {
        switch self {
        case .invalidArguments(let message):
            return message
        case .noKeyWindow:
            return "The app has no key window in the foreground"
        }
    }
}
