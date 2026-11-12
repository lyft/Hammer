import Foundation
import HammerAgentCore

@main
struct HammerCLI {
    private static let usage = """
        hammer drives an iOS or Android app that runs Hammer's agent, sending real touches and key presses \
        from inside the app.

        Usage:
          hammer <command> [--<argument> <value>]... [-] [--output <path>] [--port <port>] [--system]
                           [--android [--serial <serial>] [--app-id <application id>]]
          hammer commands         List the commands the app runs
          hammer help <command>   Describe a command, its arguments and examples
          hammer guide            Print the full guide for agents, in markdown
          hammer mcp              Run an MCP server over standard input and output

        Options:
          --output <path>  Write the command's output to a file instead of printing it
          --port <port>    The app's port. Defaults to \(AgentEndpoint.portEnvironmentKey) or \
        \(AgentEndpoint.defaultPort)
          --system         Run on the simulator's or Android device's whole screen, to reach \
        system UI such as permission alerts
          --udid <udid>    The simulator for --system. Defaults to \
        \(SimulatorCommands.udidEnvironmentKey) or the only booted one
          --android        Drive an Android app through adb instead of an iOS app
          --serial <serial>
                           The Android device, with --android. Defaults to \(Adb.serialEnvironmentKey) or \
        the only one attached
          --app-id <application id>
                           The Android app, with --android. Defaults to the only app running an agent, or \
        the focused one

        Start with `hammer describe` to see the elements on screen, and `hammer guide` for how to target \
        them and handle errors.
        """

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
        let options = try CLIOptions.extract(from: &arguments)
        var remaining = arguments[...]
        let drivers = try self.drivers(for: options)
        let driver = drivers.driver(system: options.system)
        switch remaining.popFirst() {
        case nil, "--help", "-h":
            print(self.usage)
        case "help":
            guard let name = remaining.first else {
                print(self.usage + "\n\n" + self.commandList(await driver.catalog()))
                return
            }

            print(try self.descriptor(named: name, in: await driver.catalog().commands)
                .reference(style: .commandLine))
        case "commands":
            print(self.commandList(await driver.catalog()))
        case "guide":
            let catalog = await driver.catalog()
            let guide = AgentGuide.markdown(commands: catalog.commands, style: .commandLine,
                                            platform: options.platform)
            try self.write(Data(guide.utf8), name: "guide", to: options.outputPath)
            if let note = catalog.note {
                FileHandle.standardError.write(Data("note: \(note)\n".utf8))
            }
        case "mcp":
            try await MCPServer(drivers: drivers).run()
        case let name?:
            let descriptor = try self.descriptor(named: name, in: try await driver.callableCommands())
            try self.checkAndroidOptions(in: remaining, for: descriptor, options: options)
            let commandArguments = try descriptor.arguments(from: Array(remaining))
            let output = try await driver.run(descriptor.name, arguments: commandArguments)
            try self.write(output, name: descriptor.commandLineName, to: options.outputPath)
        }
    }

    private static func drivers(for options: CLIOptions) throws -> Drivers {
        let token = AgentEndpoint.token()
        guard options.android else {
            return Drivers(app: AgentClient(port: options.port ?? AgentEndpoint.port(), token: token),
                           system: SimulatorDriver(udid: options.udid), platform: .iOS)
        }

        let adb = Adb()
        return Drivers(app: AndroidAgentClient(adb: adb, serial: options.serial, appID: options.appID,
                                               token: token),
                       system: AndroidSystemDriver(adb: adb, serial: options.serial),
                       platform: .android)
    }

    /// Explains that `--serial` and `--app-id` need `--android`, rather than calling them unknown arguments.
    private static func checkAndroidOptions(in arguments: ArraySlice<String>,
                                            for descriptor: CommandDescriptor, options: CLIOptions) throws
    {
        guard !options.android else {
            return
        }

        let names = Set(descriptor.parameters.map(\.name))
        for option in ["--serial", "--app-id"] {
            let name = String(option.dropFirst(2)).replacingOccurrences(of: "-", with: "_")
            let given = arguments.contains { $0 == option || $0.hasPrefix(option + "=") }
            if given && !names.contains(name) {
                throw UsageError(description: "\(option) only applies with --android",
                                 hint: "Add --android to drive an Android app")
            }
        }
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

    private static func commandList(_ catalog: DriverCatalog) -> String {
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
