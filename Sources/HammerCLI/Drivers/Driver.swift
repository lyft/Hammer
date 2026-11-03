import Foundation
import HammerAgentCore

/// Runs commands somewhere, such as inside the app through its agent or on the simulator from the Mac.
///
/// Every driver takes the same command language, so the CLI and MCP server only pick a driver and call it.
protocol Driver: Sendable {
    /// The commands to describe, with a note when they are not every command, so help always works.
    func catalog() async -> DriverCatalog

    /// The commands to resolve a call against.
    ///
    /// - throws: An error if the commands could not be read.
    func callableCommands() async throws -> [CommandDescriptor]

    /// Runs a command.
    ///
    /// - parameter name:      The name of the command.
    /// - parameter arguments: The arguments object.
    ///
    /// - throws: A `ClientError` if the command failed.
    ///
    /// - returns: The command's JSON output.
    func run(_ name: String, arguments: [String: JSONValue]) async throws -> Data
}

/// The drivers a call can go to.
struct Drivers: Sendable {
    /// Runs commands inside the app, through its agent.
    let app: any Driver

    /// Runs commands on the device's whole screen, including system UI such as permission alerts.
    let system: any Driver

    func driver(system: Bool) -> any Driver {
        return system ? self.system : self.app
    }
}

/// Commands to describe, with a note when they are not all of them.
struct DriverCatalog {
    let commands: [CommandDescriptor]
    let note: String?
}
