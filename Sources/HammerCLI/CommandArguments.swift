import Foundation
import HammerAgentCore

/// A command line that is invalid, such as an unknown command or argument.
struct UsageError: Error, CustomStringConvertible {
    let description: String
    var hint: String?
}

extension CommandDescriptor {
    /// Converts `--name value` or `--name=value` options to the command's arguments object, using each
    /// parameter's type. Booleans can omit the value and lists take comma separated values or repeated
    /// options. A `-` reads a JSON object of arguments from standard input, which the options override.
    ///
    /// - parameter options: The options after the command name.
    ///
    /// - throws: A `UsageError` if an option is unknown, its value does not match the type, or a required
    ///           one is missing.
    ///
    /// - returns: The arguments object.
    func arguments(from options: [String]) throws -> [String: JSONValue] {
        var arguments = [String: JSONValue]()
        var readsStandardInput = false
        var remaining = options[...]
        while let token = remaining.popFirst() {
            if token == "-" {
                readsStandardInput = true
                continue
            }

            let parts = token.split(separator: "=", maxSplits: 1).map(String.init)
            let option = parts[0]
            guard let parameter = self.parameters.first(where: { $0.optionName == option }) else {
                let suggestion = closestMatch(to: option, in: self.parameters.map(\.optionName))
                    .map { ", did you mean \($0)?" } ?? ""
                throw UsageError(
                    description: "Unknown argument \(option) for \(self.commandLineName)\(suggestion)",
                    hint: self.helpHint)
            }

            let value: String
            if parts.count == 2 {
                value = parts[1]
            } else if parameter.type == .boolean && remaining.first.map({ $0.hasPrefix("-") }) ?? true {
                value = "true"
            } else if let next = remaining.popFirst() {
                value = next
            } else {
                throw UsageError(
                    description: "Missing value for \(option), expected \(parameter.type.expectation)",
                    hint: self.helpHint)
            }

            guard let converted = parameter.type.parse(value) else {
                throw UsageError(description: """
                    Invalid value "\(value)" for \(option), expected \(parameter.type.expectation)
                    """, hint: self.helpHint)
            }

            if case .array(let values) = converted, case .array(let existing) = arguments[parameter.name] {
                arguments[parameter.name] = .array(existing + values)
            } else {
                arguments[parameter.name] = converted
            }
        }

        if readsStandardInput {
            arguments.merge(try self.standardInputArguments()) { option, _ in option }
        }

        do {
            try self.validate(arguments, style: .commandLine)
        } catch let error as ArgumentsError {
            throw UsageError(description: error.description, hint: self.helpHint)
        }

        return arguments
    }

    /// Points to the command's help, to show next to a usage error.
    var helpHint: String {
        return "Run `hammer help \(self.commandLineName)` to see its arguments and examples"
    }

    private func standardInputArguments() throws -> [String: JSONValue] {
        let data = FileHandle.standardInput.readDataToEndOfFile()
        guard let arguments = try? JSONDecoder().decode([String: JSONValue].self, from: data) else {
            throw UsageError(description: #"Standard input must be a JSON object, like {"x": 10}"#,
                             hint: self.helpHint)
        }

        return arguments
    }
}

extension CommandDescriptor.ParameterType {
    fileprivate func parse(_ string: String) -> JSONValue? {
        switch self {
        case .string:
            return .string(string)
        case .integer:
            return Int(string).map { .number(Double($0)) }
        case .number:
            return Double(string).map(JSONValue.number)
        case .boolean:
            return Bool(string).map(JSONValue.bool)
        case .stringList:
            return .array(string.split(separator: ",").map { .string(String($0)) })
        case .choice(let values):
            return values.contains(string) ? .string(string) : nil
        case .json:
            // Plain text that is not JSON, such as a color name, is passed as a string
            return (try? JSONDecoder().decode(JSONValue.self, from: Data(string.utf8))) ?? .string(string)
        }
    }
}
