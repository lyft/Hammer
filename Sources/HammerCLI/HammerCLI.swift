import Foundation
import HammerAgentCore

@main
struct HammerCLI {
    private static let usage = """
        hammer drives an iOS app that runs Hammer's agent, sending real touches and key presses from \
        inside the app.

        Usage:
          hammer <command> [--<argument> <value>]... [-] [--output <path>] [--port <port>]
          hammer commands         List the commands the app runs
          hammer help <command>   Describe a command, its arguments and examples
          hammer guide            Print the full guide for agents, in markdown
          hammer mcp              Run an MCP server over standard input and output

        Options:
          --output <path>  Write the command's output to a file instead of printing it
          --port <port>    The app's port. Defaults to \(AgentEndpoint.portEnvironmentKey) or \
        \(AgentEndpoint.defaultPort)

        Start with `hammer describe` to see the elements on screen, and `hammer guide` for how to target \
        them and handle errors.
        """

    private struct Options {
        var port = AgentEndpoint.port()
        var outputPath: String?
    }

    static func main() async {
        do {
            try await self.run(Array(CommandLine.arguments.dropFirst()))
        } catch let error as UsageError {
            self.report(AgentErrorBody(error: error.description, code: error.code, hint: error.hint))
            exit(2)
        } catch let error as ClientError {
            self.report(error.body)
            if case .failed(_, isInvalidCall: true) = error {
                exit(2)
            }

            exit(1)
        } catch {
            self.report(AgentErrorBody(error: String(describing: error), code: .failed))
            exit(1)
        }
    }

    private static func run(_ arguments: [String]) async throws {
        var arguments = arguments
        let options = try self.extractOptions(from: &arguments)
        var remaining = arguments[...]
        let client = AgentClient(port: options.port, token: AgentEndpoint.token())
        switch remaining.popFirst() {
        case nil, "--help", "-h":
            print(self.usage)
        case "help":
            guard let name = remaining.first else {
                print(self.usage + "\n\n" + self.commandList(await client.catalog()))
                return
            }

            print(try self.descriptor(named: name, in: await client.catalog().commands)
                .reference(style: .commandLine))
        case "commands":
            print(self.commandList(await client.catalog()))
        case "guide":
            let catalog = await client.catalog()
            try self.write(Data(AgentGuide.markdown(commands: catalog.commands, style: .commandLine).utf8),
                           name: "guide", to: options.outputPath)
            if let note = catalog.note {
                FileHandle.standardError.write(Data("note: \(note)\n".utf8))
            }
        case "mcp":
            try await MCPServer(client: client).run()
        case let name?:
            let descriptor = try self.descriptor(named: name, in: try await client.commandsOrBuiltins())
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
                throw UsageError(description: "Missing value for \(parts[0])", hint: "Run `hammer --help`")
            }

            if name == "output" {
                options.outputPath = value
            } else if let port = UInt16(value) {
                options.port = port
            } else {
                throw UsageError(description: "Invalid port \"\(value)\", expected a number up to 65535")
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

    private static func commandList(_ catalog: AgentClient.Catalog) -> String {
        let commands = catalog.commands.map { "  \($0.commandLineName)\n      \($0.summary)" }
        return (["Commands:"] + commands + (catalog.note.map { ["", "Note: \($0)"] } ?? []))
            .joined(separator: "\n")
    }

    private static func descriptor(named name: String, in commands: [CommandDescriptor]) throws
        -> CommandDescriptor
    {
        guard let descriptor = commands.first(where: { $0.commandLineName == name }) else {
            let names = commands.map(\.commandLineName)
            let suggestion = closestMatch(to: name, in: names).map { ", did you mean \($0)?" } ?? ""
            throw UsageError(description: "Unknown command \"\(name)\"\(suggestion)",
                             hint: "The commands are \(names.joined(separator: ", ")). Run `hammer help`",
                             code: .unknownCommand)
        }

        return descriptor
    }
}

extension HammerCLI {
    private static func report(_ body: AgentErrorBody) {
        FileHandle.standardError.write(Data((body.jsonLine + "\n").utf8))
    }
}
