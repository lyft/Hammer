import Foundation

/// Where the agent listens and the routes of its HTTP API.
///
/// `GET /commands` returns the `[CommandDescriptor]` the agent runs, and `POST /commands/<name>` runs one
/// with a JSON object of arguments, returning its JSON output or an `AgentErrorBody`. When the agent has a
/// token, requests send it as `Authorization: Bearer <token>`.
public enum AgentEndpoint {
    /// The port used when `portEnvironmentKey` is not set.
    public static let defaultPort: UInt16 = 9876

    /// The environment variable that sets the port, for both the app and its clients.
    public static let portEnvironmentKey = "HAMMER_AGENT_PORT"

    /// The environment variable that sets the token requests must send, for both the app and its clients.
    public static let tokenEnvironmentKey = "HAMMER_AGENT_TOKEN"

    /// The path that lists the commands.
    public static let commandsPath = "/commands"

    /// The port set in the environment, or the default one.
    ///
    /// - parameter environment: The environment to read.
    ///
    /// - returns: The port.
    public static func port(in environment: [String: String] = ProcessInfo.processInfo.environment)
        -> UInt16
    {
        return environment[self.portEnvironmentKey].flatMap(UInt16.init) ?? self.defaultPort
    }

    /// The token set in the environment, or nil if requests need none.
    ///
    /// - parameter environment: The environment to read.
    ///
    /// - returns: The token.
    public static func token(in environment: [String: String] = ProcessInfo.processInfo.environment)
        -> String?
    {
        return environment[self.tokenEnvironmentKey].flatMap { $0.isEmpty ? nil : $0 }
    }

    /// The path that runs a command.
    ///
    /// - parameter name: The name of the command.
    ///
    /// - returns: The path.
    public static func commandPath(_ name: String) -> String {
        return "\(self.commandsPath)/\(name)"
    }
}

/// The body of a response for a request that failed.
public struct AgentErrorBody: Codable, Sendable {
    /// What went wrong.
    public var error: String

    /// The kind of error, for clients to handle it without reading the message. Agents before 2.2 omit it.
    public var code: AgentErrorCode?

    /// How to fix it, such as the command to call first, for the agent or person that sent the request.
    public var hint: String?

    public init(error: String, code: AgentErrorCode? = nil, hint: String? = nil) {
        self.error = error
        self.code = code
        self.hint = hint
    }
}

/// A stable name for a kind of error, such as `not_found`. Commands can define their own, like
/// `AgentErrorCode("unknown_flag")`, in snake case so clients can match them.
public struct AgentErrorCode: RawRepresentable, Codable, Hashable, Sendable, ExpressibleByStringLiteral,
    CustomStringConvertible
{
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.rawValue = value
    }

    public var description: String {
        return self.rawValue
    }
}

extension AgentErrorCode {
    /// The arguments are missing, of the wrong type, or don't make sense together.
    public static let invalidArguments: Self = "invalid_arguments"
    /// The app has no command with that name.
    public static let unknownCommand: Self = "unknown_command"
    /// The request is not one the agent accepts, such as one from a browser or without the token.
    public static let invalidRequest: Self = "invalid_request"
    /// The command could not do what was asked, for a reason no other code describes.
    public static let failed: Self = "failed"
    /// No element or view matches the target.
    public static let notFound: Self = "not_found"
    /// Several elements match the target.
    public static let ambiguousTarget: Self = "ambiguous_target"
    /// The element or view is hidden, off screen or no longer on screen.
    public static let notVisible: Self = "not_visible"
    /// Something covers the element or view, or it ignores touches.
    public static let notHittable: Self = "not_hittable"
    /// The app is busy, still presenting, or another window has the keyboard focus.
    public static let notReady: Self = "not_ready"
    /// A wait ran out of time, or the app did not respond in time.
    public static let timedOut: Self = "timed_out"
    /// No agent listens on the port.
    public static let unreachable: Self = "unreachable"
    /// The app closed the connection before responding, so the command may or may not have run.
    public static let disconnected: Self = "disconnected"
    /// No simulator is booted, the one asked for is not, or Xcode can't drive it.
    public static let noSimulator: Self = "no_simulator"
}

/// An image a command outputs, such as a screenshot.
///
/// It is encoded with `"type": "image"` so clients can tell it from other outputs.
public struct AgentImage: Codable, Sendable {
    private enum CodingKeys: String, CodingKey {
        case type
        case mimeType
        case data
    }

    private enum Kind: String, Codable {
        case image
    }

    /// The media type of the data, such as `image/png`.
    public var mimeType: String

    /// The encoded image, base64 in JSON.
    public var data: Data

    public init(mimeType: String, data: Data) {
        self.mimeType = mimeType
        self.data = data
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        _ = try container.decode(Kind.self, forKey: .type)
        self.mimeType = try container.decode(String.self, forKey: .mimeType)
        self.data = try container.decode(Data.self, forKey: .data)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Kind.image, forKey: .type)
        try container.encode(self.mimeType, forKey: .mimeType)
        try container.encode(self.data, forKey: .data)
    }
}
