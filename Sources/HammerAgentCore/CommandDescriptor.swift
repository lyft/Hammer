import Foundation

/// Describes a command the agent runs, for clients to list, validate and document it.
public struct CommandDescriptor: Codable, Equatable, Sendable {
    /// The name clients call the command with, in snake case.
    public var name: String

    /// What the command does, written for the agents and people that call it.
    public var summary: String

    /// The parameters of the command's arguments object.
    public var parameters: [Parameter]

    /// Creates a command descriptor.
    ///
    /// - parameter name:       The name clients call the command with, in snake case.
    /// - parameter summary:    What the command does.
    /// - parameter parameters: The parameters of the command's arguments object.
    public init(name: String, summary: String, parameters: [Parameter] = []) {
        self.name = name
        self.summary = summary
        self.parameters = parameters
    }

    /// The JSON schema of the command's arguments object.
    public var argumentsSchema: JSONValue {
        let properties = self.parameters.map { ($0.name, $0.schema) }
        let required = self.parameters.filter(\.isRequired).map { JSONValue.string($0.name) }
        return .object([
            "type": .string("object"),
            "properties": .object(Dictionary(uniqueKeysWithValues: properties)),
            "required": .array(required),
            "additionalProperties": .bool(false),
        ])
    }
}

extension CommandDescriptor {
    /// A parameter of a command.
    public struct Parameter: Codable, Equatable, Sendable {
        /// The name of the argument.
        public var name: String

        /// The type of the argument's value.
        public var type: ParameterType

        /// What the argument does.
        public var summary: String

        /// If the argument must be passed.
        public var isRequired: Bool

        /// Creates a parameter.
        ///
        /// - parameter name:       The name of the argument.
        /// - parameter type:       The type of the argument's value.
        /// - parameter summary:    What the argument does.
        /// - parameter isRequired: If the argument must be passed.
        public init(_ name: String, _ type: ParameterType, _ summary: String, isRequired: Bool = false) {
            self.name = name
            self.type = type
            self.summary = summary
            self.isRequired = isRequired
        }

        var schema: JSONValue {
            var schema = self.type.schema
            schema["description"] = .string(self.summary)
            return .object(schema)
        }
    }

    /// The type of a parameter's value.
    public enum ParameterType: Codable, Equatable, Sendable {
        case string
        case integer
        case number
        case boolean
        case stringList
        case choice([String])

        var schema: [String: JSONValue] {
            switch self {
            case .string:
                return ["type": .string("string")]
            case .integer:
                return ["type": .string("integer")]
            case .number:
                return ["type": .string("number")]
            case .boolean:
                return ["type": .string("boolean")]
            case .stringList:
                return ["type": .string("array"), "items": .object(["type": .string("string")])]
            case .choice(let values):
                return ["type": .string("string"), "enum": .array(values.map(JSONValue.string))]
            }
        }
    }
}
