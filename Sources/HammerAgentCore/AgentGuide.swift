import Foundation

/// Instructions for agents that drive the app, generated from the commands so they never fall behind.
public enum AgentGuide {
    /// How the guide shows calls, for the client that reads it.
    public enum Style: Sendable {
        /// `hammer` commands with `--argument value` options.
        case commandLine

        /// Tool calls with a JSON arguments object, for MCP.
        case tools
    }

    /// How to use the commands, without the reference of each one.
    ///
    /// - parameter style: How to show calls.
    ///
    /// - returns: The markdown.
    public static func overview(style: Style) -> String {
        let tap = style == .commandLine ? "`hammer tap --ref e12`" : #"`tap` with `{"ref":"e12"}`"#
        let usage = self.usage.replacingOccurrences(of: "{tap}", with: tap)
        guard style == .commandLine else {
            return usage
        }

        let commandLineUsage = BuiltinCommands.all.reduce(usage) { usage, command in
            usage.replacingOccurrences(of: "`\(command.name)`", with: "`\(command.commandLineName)`")
        }

        return commandLineUsage + "\n\n" + self.commandLine
    }

    private static let usage = """
        # Hammer agent

        Hammer drives an iOS app from inside it: it finds views and accessibility elements, including \
        SwiftUI's, and sends real touch and keyboard events, waiting for the app to process each one. It can \
        only reach the app's own windows, not system UI such as permission alerts or the home screen, and it \
        runs one command at a time.

        ## Workflow

        1. Call `describe` to see the elements on screen, with their ref, identifier, label, value, traits, \
        frame and whether touches reach them (`hittable`).
        2. Act on an element, such as {tap}.
        3. After an action that changes the screen, call `wait_for` with an element of the next state, or \
        `wait_for_idle` for animations, then `describe` or `screenshot` again to check the result.

        ## Targeting

        Commands that act on an element take one of:

        - `ref`: the ref from `describe`, such as `e12`. It is the most precise and stays the same while the \
        element exists. Call `describe` again if a ref is unknown.
        - `identifier`, `label`, `value` and `traits`: every one given must match. When several elements \
        match, add more of them or use the `ref`.
        - `x` and `y`: a point in window points, the same coordinates as the frames from `describe`.

        Without a target, gestures use the center of the window.

        ## Live editing

        To see how a change looks, or which change fixes a layout problem, before writing it in code:

        1. Find the view with `describe`, or with `hierarchy` for containers and hidden views that \
        `describe` leaves out.
        2. Call `inspect` on it to see its properties, with their types and values, and the constraints \
        that lay it out, with their refs such as `c4`.
        3. Change it with `set_property`, `set_constraint` or `add_constraint`, then `screenshot` to see \
        the result, with a `ref` to capture only that view.
        4. Call `revert` when done. It restores every original value, since the app keeps the changes until \
        it relaunches.

        ## Errors

        A failed command explains what went wrong and gives a hint on how to fix it, such as calling \
        `describe` to find an element, scrolling to an element that is off screen, or the arguments the \
        command takes. Fix the call and try again rather than retrying it unchanged.
        """

    private static let commandLine = """
        ## Command line

        - `hammer commands` lists the commands and `hammer help <command>` describes one.
        - Pass arguments as `--name value` or `--name=value`. Lists take comma separated values, and \
        booleans can leave out `true`.
        - A trailing `-` reads a JSON object of arguments from standard input, for nested values.
        - `--output <path>` writes the output to a file, and `--port <port>` picks the app's port.
        - Output is JSON on standard output. Screenshots are written to a PNG file and its path is printed, \
        so open that file to see it.
        - Failures print `error:` and `hint:` lines to standard error and exit with 1, or with 2 when the \
        call itself is invalid, such as an unknown command or argument.
        """

    /// The overview followed by the reference of every command.
    ///
    /// - parameter commands: The commands the app runs.
    /// - parameter style:    How to show calls.
    ///
    /// - returns: The markdown.
    public static func markdown(commands: [CommandDescriptor], style: Style) -> String {
        let reference = commands.map { $0.reference(style: style) }
        return ([self.overview(style: style), "## Commands"] + reference).joined(separator: "\n\n") + "\n"
    }
}

extension CommandDescriptor {
    /// The name of the command on the command line, such as `type-text` for `type_text`.
    public var commandLineName: String {
        return self.name.replacingOccurrences(of: "_", with: "-")
    }

    /// The command's section of the guide.
    ///
    /// - parameter style: How to show calls.
    ///
    /// - returns: The markdown.
    public func reference(style: AgentGuide.Style) -> String {
        let name = style == .commandLine ? self.commandLineName : self.name
        var lines = ["### \(name)", "", self.summary]
        if !self.parameters.isEmpty {
            lines.append("")
            lines += self.parameters.map { parameter in
                let label = style == .commandLine ? parameter.optionName : parameter.name
                let required = parameter.isRequired ? ", required" : ""
                return "- `\(label)` (\(parameter.type.expectation)\(required)): \(parameter.summary)"
            }
        }

        if !self.examples.isEmpty {
            let examples = self.examples.flatMap { example in
                ["# \(example.summary)", self.call(example, style: style)]
            }

            lines += ["", "```" + (style == .commandLine ? "sh" : "")] + examples + ["```"]
        }

        return lines.joined(separator: "\n")
    }

    /// The example as a call in the style.
    ///
    /// - parameter example: The example.
    /// - parameter style:   How to show the call.
    ///
    /// - returns: The call.
    public func call(_ example: Example, style: AgentGuide.Style) -> String {
        guard style == .commandLine else {
            return "\(self.name) \(JSONValue.object(example.arguments).compactDescription)"
        }

        // Follow the parameters' order so examples read like the reference
        let options = self.parameters.compactMap { parameter -> String? in
            guard let value = example.arguments[parameter.name] else {
                return nil
            }

            switch value {
            case .bool(true):
                return parameter.optionName
            case .string(let string):
                return "\(parameter.optionName) \(shellQuoted(string))"
            case .array(let values) where parameter.type == .stringList:
                let strings = values.map { if case .string(let string) = $0 { string } else { "" } }
                return "\(parameter.optionName) \(shellQuoted(strings.joined(separator: ",")))"
            default:
                return "\(parameter.optionName) \(shellQuoted(value.compactDescription))"
            }
        }

        return (["hammer", self.commandLineName] + options).joined(separator: " ")
    }
}

extension CommandDescriptor.Parameter {
    /// The option for the parameter, such as `--to-identifier` for `to_identifier`.
    public var optionName: String {
        return Self.optionName(for: self.name)
    }

    /// The option for a parameter name, such as `--to-identifier` for `to_identifier`.
    ///
    /// - parameter name: The parameter name.
    ///
    /// - returns: The option.
    public static func optionName(for name: String) -> String {
        return "--" + name.replacingOccurrences(of: "_", with: "-")
    }
}

private func shellQuoted(_ string: String) -> String {
    let safe = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "@%+=:,./-_"))
    guard !string.isEmpty, string.unicodeScalars.allSatisfy(safe.contains) else {
        return "'" + string.replacingOccurrences(of: "'", with: #"'\''"#) + "'"
    }

    return string
}
