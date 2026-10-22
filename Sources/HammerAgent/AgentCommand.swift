import Foundation
import Hammer
import HammerAgentCore
import UIKit

/// A command the agent runs for its clients, such as a tap or an app specific action like signing in.
@MainActor
public protocol AgentCommand {
    /// The arguments, decoded from the JSON object the client sends.
    associatedtype Arguments: Decodable

    /// The output, encoded as the JSON the client receives.
    associatedtype Output: Encodable

    /// Describes the command to clients. The parameters must match the keys `Arguments` decodes and can't
    /// use `CommandDescriptor.reservedParameterNames`.
    var descriptor: CommandDescriptor { get }

    /// Runs the command.
    ///
    /// - parameter arguments: The arguments from the client.
    /// - parameter context:   The state of this run, such as the event generator for the key window.
    ///
    /// - throws: An error to report to the client.
    ///
    /// - returns: The output for the client.
    func run(_ arguments: Arguments, in context: AgentContext) async throws -> Output
}

/// The output of a command that only reports it succeeded.
public struct NoOutput: Encodable, Sendable {
    public init() {}
}

/// The state of one command run.
@MainActor
public final class AgentContext {
    private var generator: EventGenerator?
    let references: ElementReferences

    init(references: ElementReferences) {
        self.references = references
    }

    /// Returns the ref clients use to target the element in later commands.
    ///
    /// - parameter element: The element.
    ///
    /// - returns: The ref.
    public func ref(for element: AccessibilityElement) -> String {
        return self.references.ref(for: element)
    }

    /// Returns the element a ref from `ref(for:)` points to.
    ///
    /// - parameter ref: The ref.
    ///
    /// - throws: An error if the ref is unknown or its element was released.
    ///
    /// - returns: The element.
    public func element(for ref: String) throws -> AccessibilityElement {
        return try self.references.element(for: ref)
    }

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

/// An error a command reports to the client, with a hint on how to fix it.
public enum AgentError: Error, CustomStringConvertible {
    /// The arguments do not make sense together or refer to something that does not exist.
    case invalidArguments(String, hint: String? = nil)

    /// The command could not do what was asked.
    case failed(String, hint: String? = nil)

    /// The app has no foreground key window to send events to.
    case noKeyWindow

    public var description: String {
        switch self {
        case .invalidArguments(let message, _), .failed(let message, _):
            return message
        case .noKeyWindow:
            return "The app has no key window in the foreground"
        }
    }

    /// How to fix the error.
    public var hint: String? {
        switch self {
        case .invalidArguments(_, let hint), .failed(_, let hint):
            return hint
        case .noKeyWindow:
            return "Bring the app to the foreground, it may be in the background or still launching"
        }
    }
}
