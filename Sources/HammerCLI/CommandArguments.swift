import Foundation
import HammerAgentCore

struct UsageError: Error, CustomStringConvertible {
    let description: String
}

extension CommandDescriptor {
    /// Converts `--name value` options to the command's arguments object, using each parameter's type.
    /// Booleans can omit the value and lists take comma separated values or repeated options.
    ///
    /// - parameter options: The options after the command name.
    ///
    /// - throws: A `UsageError` if an option is unknown or its value does not match the type.
    ///
    /// - returns: The arguments object.
    func arguments(from options: [String]) throws -> [String: JSONValue] {
        var arguments = [String: JSONValue]()
        var remaining = options[...]
        while let option = remaining.popFirst() {
            guard option.hasPrefix("--"), let parameter = self.parameter(forOption: option) else {
                throw UsageError(description: "Unknown option \(option) for \(self.commandLineName)")
            }

            let value: String
            if parameter.type == .boolean && remaining.first.map({ $0.hasPrefix("--") }) ?? true {
                value = "true"
            } else if let next = remaining.popFirst() {
                value = next
            } else {
                throw UsageError(description: "Missing value for \(option)")
            }

            let converted = try parameter.type.value(from: value, option: option)
            if case .array(let values) = converted, case .array(let existing) = arguments[parameter.name] {
                arguments[parameter.name] = .array(existing + values)
            } else {
                arguments[parameter.name] = converted
            }
        }

        if let missing = self.parameters.first(where: { $0.isRequired && arguments[$0.name] == nil }) {
            throw UsageError(
                description: "Missing option \(missing.optionName) for \(self.commandLineName)")
        }

        return arguments
    }

    /// The help text for the command.
    var usage: String {
        let options = self.parameters.map { parameter in
            let required = parameter.isRequired ? " (required)" : ""
            let option = "  \(parameter.optionName) <\(parameter.type.placeholder)>\(required)"
            return "\(option)\n      \(parameter.summary)"
        }

        let header = ["hammer \(self.commandLineName) [options]", "", self.summary]
        return (header + (options.isEmpty ? [] : [""] + options)).joined(separator: "\n")
    }

    /// The name of the command on the command line, such as `type-text` for `type_text`.
    var commandLineName: String {
        return self.name.replacingOccurrences(of: "_", with: "-")
    }

    private func parameter(forOption option: String) -> Parameter? {
        return self.parameters.first { $0.optionName == option }
    }
}

extension CommandDescriptor.Parameter {
    /// The option for the parameter, such as `--to-identifier` for `to_identifier`.
    var optionName: String {
        return "--" + self.name.replacingOccurrences(of: "_", with: "-")
    }
}

extension CommandDescriptor.ParameterType {
    fileprivate var placeholder: String {
        switch self {
        case .string:
            return "text"
        case .integer:
            return "integer"
        case .number:
            return "number"
        case .boolean:
            return "true|false"
        case .stringList:
            return "a,b,..."
        case .choice(let values):
            return values.joined(separator: "|")
        }
    }

    fileprivate func value(from string: String, option: String) throws -> JSONValue {
        let invalid = UsageError(
            description: "Invalid value \"\(string)\" for \(option), expected \(self.placeholder)")
        switch self {
        case .string:
            return .string(string)
        case .integer:
            guard let integer = Int(string) else {
                throw invalid
            }

            return .number(Double(integer))
        case .number:
            guard let number = Double(string) else {
                throw invalid
            }

            return .number(number)
        case .boolean:
            guard let bool = Bool(string) else {
                throw invalid
            }

            return .bool(bool)
        case .stringList:
            return .array(string.split(separator: ",").map { .string(String($0)) })
        case .choice(let values):
            guard values.contains(string) else {
                throw invalid
            }

            return .string(string)
        }
    }
}
