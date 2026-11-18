import Foundation
import HammerAgentCore

/// The `hammer` tool's own options, which can go anywhere in the arguments since commands can't use their
/// names.
struct CLIOptions: Equatable {
    var port: UInt16?
    var outputPath: String?
    var system = false
    var udid: String?
    var android = false
    var serial: String?
    var appID: String?

    /// The options that take true or false, and are true when given alone.
    static let flagNames: Set<String> = ["system", "android"]

    /// The platform the options drive.
    var platform: AgentPlatform {
        return self.android ? .android : .iOS
    }

    /// Removes the tool's options from the arguments and checks they fit together.
    ///
    /// `--serial` and `--app-id` are only the tool's with `--android`, so an iOS command can still take
    /// parameters with those names.
    ///
    /// - parameter arguments: The arguments, left with the command and its own options.
    ///
    /// - throws: A `UsageError` for an invalid value or options that don't fit together.
    ///
    /// - returns: The options.
    static func extract(from arguments: inout [String]) throws -> CLIOptions {
        var options = CLIOptions()
        let values = self.valuePositions(in: arguments)
        let android = arguments.indices.contains { index in
            !values.contains(index) && ["--android", "--android=true"].contains(arguments[index])
        }
        let names = CommandDescriptor.reservedParameterNames(for: android ? .android : .iOS)
        var remaining = [String]()
        var index = 0
        while index < arguments.count {
            let token = arguments[index]
            index += 1
            // Keeping empty parts makes an empty argument, such as the value of --label "", one empty part
            let parts = token.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
                .map(String.init)
            // Options are kebab case, such as --app-id for the reserved name app_id
            let name = parts[0].hasPrefix("--")
                ? String(parts[0].dropFirst(2)).replacingOccurrences(of: "-", with: "_") : ""
            guard !values.contains(index - 1), names.contains(name) else {
                remaining.append(token)
                continue
            }

            if self.flagNames.contains(name) {
                guard let flag = parts.count == 2 ? Bool(parts[1]) : true else {
                    throw UsageError(description: """
                        Invalid value "\(parts[1])" for \(parts[0]), expected true or false
                        """)
                }

                options.setFlag(name, to: flag)
                continue
            }

            let value: String
            if parts.count == 2 {
                value = parts[1]
            } else if index < arguments.count {
                value = arguments[index]
                index += 1
            } else {
                throw UsageError(description: "Missing value for \(parts[0])", hint: "Run `hammer --help`")
            }

            try options.set(name, to: value)
        }

        try options.validate()
        arguments = remaining
        return options
    }

    /// The positions of the arguments that are values of the command's own options, such as `--android` in
    /// `type-text --text --android`, so they aren't read as the tool's options. This knows the built-in
    /// commands only, since a custom one is described by the app, so a custom command's value that starts
    /// with `--` is passed as `--name=value`.
    static func valuePositions(in arguments: [String]) -> Set<Int> {
        guard let command = arguments.first else {
            return []
        }

        let descriptors = BuiltinCommands.all + BuiltinCommands.all(for: .android) + AndroidSystemCommands.all
            + SimulatorCommands.all
        let valueOptions = Set(descriptors.filter { $0.commandLineName == command }
            .flatMap(\.parameters)
            .filter { parameter in
                if case .boolean = parameter.type {
                    return false
                }
                return true
            }
            .map(\.optionName))
        var positions = Set<Int>()
        var index = 1
        while index < arguments.count {
            if valueOptions.contains(arguments[index]) {
                positions.insert(index + 1)
                index += 2
            } else {
                index += 1
            }
        }

        return positions
    }

    private mutating func setFlag(_ name: String, to flag: Bool) {
        switch name {
        case "system":
            self.system = flag
        case "android":
            self.android = flag
        default:
            preconditionFailure("\(name) is not a flag")
        }
    }

    private mutating func set(_ name: String, to value: String) throws {
        switch name {
        case "output":
            self.outputPath = value
        case "udid":
            self.udid = value
        case "serial":
            self.serial = value
        case "app_id":
            self.appID = value
        case "port":
            guard let port = UInt16(value) else {
                throw UsageError(description: "Invalid port \"\(value)\", expected a number up to 65535")
            }

            self.port = port
        default:
            preconditionFailure("\(name) is not an option")
        }
    }

    /// Rejects options that do nothing with the others, rather than ignoring them.
    private func validate() throws {
        guard self.android else {
            return
        }

        if self.port != nil {
            throw UsageError(description: "--port doesn't apply with --android", hint: """
                The agent is reached through adb: pick the device with --serial and the app with --app-id
                """)
        }

        if self.udid != nil {
            throw UsageError(description: "--udid picks a simulator, which doesn't apply with --android",
                             hint: "Pick the device with --serial")
        }

        if self.system && self.appID != nil {
            throw UsageError(description: """
                --app-id doesn't apply with --system, which drives the whole screen
                """, hint: "Leave out --app-id, or --system to run the command in the app")
        }
    }
}
