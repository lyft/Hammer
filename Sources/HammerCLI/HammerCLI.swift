import Foundation
import HammerAgentCore

@main
struct HammerCLI {
    private static let usage = """
        Drives an iOS app that runs Hammer's agent.

        Usage:
          hammer [--port <port>] <command> [--<option> <value>]...
          hammer [--port <port>] commands         List the commands the app runs
          hammer [--port <port>] help <command>   Describe a command and its options
          hammer [--port <port>] mcp              Run an MCP server over standard input and output

        Commands print their JSON output. Images, such as screenshots, are written to --output, or to a PNG
        file in the current directory.

        The port defaults to \(AgentEndpoint.portEnvironmentKey) or \(AgentEndpoint.defaultPort).
        """

    static func main() async {
        do {
            try await self.run(Array(CommandLine.arguments.dropFirst()))
        } catch {
            FileHandle.standardError.write(Data("error: \(error)\n".utf8))
            exit(1)
        }
    }

    private static func run(_ arguments: [String]) async throws {
        var arguments = arguments[...]
        var port = AgentEndpoint.port()
        if arguments.first == "--port" {
            arguments.removeFirst()
            guard let value = arguments.popFirst().flatMap(UInt16.init) else {
                throw UsageError(description: "Invalid port")
            }

            port = value
        }

        let client = AgentClient(port: port)
        switch arguments.popFirst() {
        case nil, "--help", "-h":
            print(self.usage)
        case "help":
            guard let name = arguments.first else {
                print(self.usage)
                return
            }

            print(try self.descriptor(named: name, in: await client.commandsOrBuiltins()).usage)
        case "commands":
            for command in try await client.commands() {
                print("\(command.commandLineName)\n    \(command.summary)")
            }
        case "mcp":
            try await MCPServer(client: client).run()
        case let name?:
            try await self.runCommand(name, options: Array(arguments), client: client)
        }
    }

    private static func runCommand(_ name: String, options: [String], client: AgentClient) async throws {
        var options = options
        var outputPath: String?
        if let index = options.firstIndex(of: "--output") {
            guard index + 1 < options.count else {
                throw UsageError(description: "Missing value for --output")
            }

            outputPath = options[index + 1]
            options.removeSubrange(index...(index + 1))
        }

        let descriptor = try self.descriptor(named: name, in: await client.commandsOrBuiltins())
        let output = try await client.run(descriptor.name, arguments: try descriptor.arguments(from: options))
        if let image = try? JSONDecoder().decode(AgentImage.self, from: output) {
            let path = outputPath ?? "\(name)-\(Int(Date().timeIntervalSince1970)).png"
            try image.data.write(to: URL(filePath: path))
            print(path)
        } else {
            print(String(bytes: output, encoding: .utf8) ?? "")
        }
    }

    private static func descriptor(named name: String, in commands: [CommandDescriptor]) throws
        -> CommandDescriptor
    {
        guard let descriptor = commands.first(where: { $0.commandLineName == name }) else {
            let names = commands.map(\.commandLineName).joined(separator: ", ")
            throw UsageError(description: "Unknown command \"\(name)\". The commands are: \(names)")
        }

        return descriptor
    }
}
