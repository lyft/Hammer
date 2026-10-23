@_exported import HammerAgentCore
import Foundation

/// Lets AI agents and scripts drive the app through Hammer, with the `hammer` command line tool or its MCP
/// server. By default it only accepts connections from the same device, which includes the Mac running a
/// simulator.
///
/// ⚠️ IMPORTANT: Like Hammer, this uses private APIs and must only be started in debug builds.
@MainActor
public final class HammerAgent {
    private let router = CommandRouter()
    private let requestedPort: UInt16
    private var server: HTTPServer?

    /// Creates an agent with the builtin commands.
    ///
    /// - parameter port: The port to listen on, 0 for any free one. Defaults to `HAMMER_AGENT_PORT` or 9876.
    public init(port: UInt16 = AgentEndpoint.port()) {
        self.requestedPort = port
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
    /// - parameter allowsRemoteConnections: If other devices on the network can connect, such as to drive a
    ///                                      physical device from a Mac. Anyone who can reach the device can
    ///                                      then control the app, since there is no authentication.
    ///
    /// - throws: An error if the port is not available.
    public func start(allowsRemoteConnections: Bool = false) async throws {
        guard self.server == nil else {
            return
        }

        let router = self.router
        let server = try HTTPServer(port: self.requestedPort,
                                    allowsRemoteConnections: allowsRemoteConnections) { request in
            await router.respond(to: request)
        }

        try await server.start()
        self.server = server
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
