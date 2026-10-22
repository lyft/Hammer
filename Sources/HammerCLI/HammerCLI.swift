import Foundation
import HammerAgentCore

@main
struct HammerCLI {
    private static let usage = """
        Drives an iOS app that runs Hammer's agent.

        Usage:
          hammer <command> [--<argument> <value>]... [-] [<options>]
          hammer commands         List the commands the app runs
          hammer help <command>   Describe a command and its arguments
          hammer mcp              Run an MCP server over standard input and output

        Options:
          --port <port>    The agent's port. Defaults to \(AgentEndpoint.portEnvironmentKey) or \
        \(AgentEndpoint.defaultPort).
          --output <path>  Write the command's output to a file instead of printing it.

        Arguments also take the form --<argument>=<value>. A - reads a JSON object of arguments from
        standard input, for values such as nested objects. Commands print their JSON output, and write
        images such as screenshots to a PNG file in the current directory.
        """

    private struct Options {
        var port = AgentEndpoint.port()
        var outputPath: String?
    }

    static func main() async {
        do {
            try await self.run(Array(CommandLine.arguments.dropFirst()))
        } catch {
            FileHandle.standardError.write(Data("error: \(error)\n".utf8))
            exit(1)
        }
    }

    private static func run(_ arguments: [String]) async throws {
        var arguments = arguments
        let options = try self.extractOptions(from: &arguments)
        var remaining = arguments[...]
        let client = AgentClient(port: options.port)
        switch remaining.popFirst() {
        case nil, "--help", "-h":
            print(self.usage)
        case "help":
            guard let name = remaining.first else {
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
            let descriptor = try self.descriptor(named: name, in: await client.commandsOrBuiltins())
            let commandArguments = try descriptor.arguments(from: Array(remaining))
            let output = try await client.run(descriptor.name, arguments: commandArguments)
            try self.write(output, name: descriptor.commandLineName, to: options.outputPath)
        }
    }

    /// Removes the tool's own options, which can go anywhere since commands can't use their names.
    private static func extractOptions(from arguments: inout [String]) throws -> Options {
        var options = Options()
        var remaining = [String]()
        var tokens = arguments[...]
        while let token = tokens.popFirst() {
            let parts = token.split(separator: "=", maxSplits: 1).map(String.init)
            let name = parts[0].hasPrefix("--") ? String(parts[0].dropFirst(2)) : ""
            guard CommandDescriptor.reservedParameterNames.contains(name) else {
                remaining.append(token)
                continue
            }

            guard let value = parts.count == 2 ? parts[1] : tokens.popFirst() else {
                throw UsageError(description: "Missing value for \(parts[0])")
            }

            if parts[0] == "--output" {
                options.outputPath = value
            } else if let port = UInt16(value) {
                options.port = port
            } else {
                throw UsageError(description: "Invalid port \"\(value)\"")
            }
        }

        arguments = remaining
        return options
    }

    /// Prints the output or writes it to the path. Images are always written to a file, as image data.
    private static func write(_ output: Data, name: String, to outputPath: String?) throws {
        if let image = try? JSONDecoder().decode(AgentImage.self, from: output) {
            let path = outputPath ?? "\(name)-\(Int(Date().timeIntervalSince1970)).png"
            try image.data.write(to: URL(filePath: path))
            print(path)
        } else if let outputPath {
            try output.write(to: URL(filePath: outputPath))
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
