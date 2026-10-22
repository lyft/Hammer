import Foundation

/// A problem with the arguments of a command, explained so the caller can correct them.
public struct ArgumentsError: Error, CustomStringConvertible, Sendable {
    /// What is wrong.
    public let description: String

    /// How to fix it.
    public let hint: String

    public init(_ description: String, hint: String) {
        self.description = description
        self.hint = hint
    }
}

extension CommandDescriptor {
    /// Checks that the arguments are declared, have the parameter's type and include the required ones.
    ///
    /// - parameter arguments: The arguments object.
    /// - parameter style:     How to name the command and arguments in errors.
    ///
    /// - throws: An `ArgumentsError` that names the argument and what it expects.
    public func validate(_ arguments: [String: JSONValue], style: AgentGuide.Style = .tools) throws {
        let command = style == .commandLine ? self.commandLineName : self.name
        let label = { (name: String) in
            style == .commandLine ? Parameter.optionName(for: name) : #""\#(name)""#
        }
        for (name, value) in arguments.sorted(by: { $0.key < $1.key }) {
            guard let parameter = self.parameters.first(where: { $0.name == name }) else {
                let suggestion = closestMatch(to: name, in: self.parameters.map(\.name))
                    .map { ", did you mean \(label($0))?" } ?? ""
                throw ArgumentsError("Unknown argument \(label(name)) for \(command)\(suggestion)",
                                     hint: self.argumentsHint)
            }

            guard parameter.type.accepts(value) else {
                throw ArgumentsError("""
                    Invalid value \(value.compactDescription) for \(label(name)), expected \
                    \(parameter.type.expectation)
                    """, hint: self.argumentsHint)
            }
        }

        if let missing = self.parameters.first(where: { $0.isRequired && arguments[$0.name] == nil }) {
            throw ArgumentsError("""
                Missing required argument \(label(missing.name)) for \(command), expected \
                \(missing.type.expectation)
                """, hint: self.argumentsHint)
        }
    }

    /// Lists the arguments the command takes, to show next to an argument error.
    public var argumentsHint: String {
        guard !self.parameters.isEmpty else {
            return "\(self.name) takes no arguments"
        }

        let parameters = self.parameters.map { parameter in
            "\(parameter.name)\(parameter.isRequired ? " (required)" : ""): \(parameter.type.expectation)"
        }

        return "\(self.name) takes " + parameters.joined(separator: "; ")
    }
}

extension CommandDescriptor.ParameterType {
    /// What the type expects, such as `an integer` or `one of up, down`.
    public var expectation: String {
        switch self {
        case .string:
            return "a string"
        case .integer:
            return "an integer"
        case .number:
            return "a number"
        case .boolean:
            return "true or false"
        case .stringList:
            return "a list of strings"
        case .choice(let values):
            return "one of " + values.joined(separator: ", ")
        case .json:
            return "any JSON value"
        }
    }

    fileprivate func accepts(_ value: JSONValue) -> Bool {
        switch (self, value) {
        case (.string, .string), (.number, .number), (.boolean, .bool), (.json, _):
            return true
        case (.integer, .number(let number)):
            return number.rounded() == number
        case (.stringList, .array(let values)):
            return values.allSatisfy { if case .string = $0 { true } else { false } }
        case (.choice(let values), .string(let string)):
            return values.contains(string)
        default:
            return false
        }
    }
}

extension JSONValue {
    /// The value as compact JSON, to quote it in errors.
    public var compactDescription: String {
        guard let data = try? JSONEncoder().encode(self) else {
            return "\(self)"
        }

        return String(bytes: data, encoding: .utf8) ?? "\(self)"
    }
}

/// Returns the candidate closest to the name, to suggest it for a typo, or nil if none is close.
///
/// - parameter name:       The name that was not found.
/// - parameter candidates: The valid names.
///
/// - returns: The closest candidate.
public func closestMatch(to name: String, in candidates: [String]) -> String? {
    let scored = candidates.map { ($0, editDistance(name.lowercased(), $0.lowercased())) }
    guard let (candidate, distance) = scored.min(by: { $0.1 < $1.1 }) else {
        return nil
    }

    return distance <= max(2, name.count / 3) ? candidate : nil
}

private func editDistance(_ lhs: String, _ rhs: String) -> Int {
    let lhs = Array(lhs)
    let rhs = Array(rhs)
    var previous = Array(0...rhs.count)
    for (i, lhsCharacter) in lhs.enumerated() {
        var current = [i + 1]
        for (j, rhsCharacter) in rhs.enumerated() {
            current.append(min(previous[j + 1] + 1, current[j] + 1,
                               previous[j] + (lhsCharacter == rhsCharacter ? 0 : 1)))
        }

        previous = current
    }

    return previous[rhs.count]
}
