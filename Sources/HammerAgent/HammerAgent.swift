@_exported import HammerAgentCore
import Foundation
import OSLog

/// Lets AI agents and scripts drive the app through Hammer, with the `hammer` command line tool or its MCP
/// server. By default it only runs in the simulator and accepts connections from the same device, which
/// includes the Mac running the simulator.
///
/// ⚠️ IMPORTANT: Like Hammer, this uses private APIs and must only be started in debug builds.
@MainActor
public final class HammerAgent {
    private static let logger = Logger(subsystem: "com.lyft.hammer", category: "agent")

    private let router = CommandRouter()
    private let requestedPort: UInt16
    private let token: String?
    private var server: HTTPServer?

    /// Creates an agent with the builtin commands.
    ///
    /// - parameter port:  The port to listen on, 0 for any free one. Defaults to `HAMMER_AGENT_PORT` or 9876.
    /// - parameter token: The token requests must send, or nil for none. Defaults to `HAMMER_AGENT_TOKEN`.
    public init(port: UInt16 = AgentEndpoint.port(), token: String? = AgentEndpoint.token()) {
        self.requestedPort = port
        self.token = token
        for command in Self.builtinCommands {
            self.router.register(command)
        }
    }

    /// The port the agent listens on, or nil if it is not running.
    public var port: UInt16? {
        return self.server?.port
    }

    /// The commands the agent runs, in the order they were registered.
    public var commands: [CommandDescriptor] {
        return self.router.descriptors
    }

    /// Adds a command, or replaces the one with the same name.
    ///
    /// - parameter command: The command to add.
    public func register(_ command: some AgentCommand) {
        self.router.register(command)
    }

    /// Starts listening for commands. Does nothing if the agent is already listening.
    ///
    /// - parameter allowsPhysicalDevice:    If the agent runs on a physical device rather than only in the
    ///                                      simulator, where other apps on the device can connect to it.
    /// - parameter allowsRemoteConnections: If other devices on the network can connect, such as to drive a
    ///                                      physical device from a Mac. Requires a token.
    ///
    /// - throws: An `AgentStartError` if the options are unsafe, or an error if the port is not available.
    public func start(allowsPhysicalDevice: Bool = false, allowsRemoteConnections: Bool = false)
        async throws
    {
        guard self.server == nil else {
            return
        }

        #if !targetEnvironment(simulator)
        guard allowsPhysicalDevice else {
            throw AgentStartError.physicalDevice
        }
        #endif

        guard !allowsRemoteConnections || self.token != nil else {
            throw AgentStartError.remoteConnectionsWithoutToken
        }

        let router = self.router
        let server = try HTTPServer(port: self.requestedPort,
                                    allowsRemoteConnections: allowsRemoteConnections,
                                    token: self.token) { request in
            await router.respond(to: request)
        }

        try await server.start()
        self.server = server

        let reach = allowsRemoteConnections ? "any device on the network" : "this device"
        let access = self.token == nil ? "without a token" : "with its token"
        Self.logger.notice("""
            Hammer agent listening on port \(server.port ?? 0, privacy: .public), anything on \
            \(reach, privacy: .public) can control this app \(access, privacy: .public)
            """)
    }

    /// Stops listening for commands.
    public func stop() {
        self.server?.stop()
        self.server = nil
    }

    private static let builtinCommands: [any AgentCommand] = [
        DescribeCommand(), HierarchyCommand(), InspectCommand(), TapCommand(), LongPressCommand(),
        SwipeCommand(), EdgeSwipeCommand(), DragCommand(), TypeTextCommand(), PressKeyCommand(),
        WaitForCommand(), WaitForIdleCommand(), ScreenshotCommand(), SetPropertyCommand(),
        SetConstraintCommand(), AddConstraintCommand(), RevertCommand(),
    ]
}

/// Why the agent refused to start, since the options would expose the app more than intended.
public enum AgentStartError: Error, CustomStringConvertible {
    /// The app runs on a physical device and `allowsPhysicalDevice` is false.
    case physicalDevice

    /// `allowsRemoteConnections` is true and the agent has no token.
    case remoteConnectionsWithoutToken

    public var description: String {
        switch self {
        case .physicalDevice:
            return """
                The Hammer agent only runs in the simulator by default. Pass allowsPhysicalDevice to start() \
                to run it on a device, where other apps can connect to it
                """
        case .remoteConnectionsWithoutToken:
            return """
                The Hammer agent needs a token to accept remote connections. Set \
                \(AgentEndpoint.tokenEnvironmentKey) or pass a token to HammerAgent
                """
        }
    }
}
