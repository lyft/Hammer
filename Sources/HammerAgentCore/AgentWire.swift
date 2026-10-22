import Foundation

/// Where the agent listens and the routes of its HTTP API.
///
/// `GET /commands` returns the `[CommandDescriptor]` the agent runs, and `POST /commands/<name>` runs one
/// with a JSON object of arguments, returning its JSON output or an `AgentErrorBody`.
public enum AgentEndpoint {
    /// The port used when `portEnvironmentKey` is not set.
    public static let defaultPort: UInt16 = 9876

    /// The environment variable that sets the port, for both the app and its clients.
    public static let portEnvironmentKey = "HAMMER_AGENT_PORT"

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

    /// How to fix it, such as the command to call first, for the agent or person that sent the request.
    public var hint: String?

    public init(error: String, hint: String? = nil) {
        self.error = error
        self.hint = hint
    }
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
