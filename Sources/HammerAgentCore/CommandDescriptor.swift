import Foundation

/// Describes a command the agent runs, for clients to list, validate and document it.
public struct CommandDescriptor: Codable, Equatable, Sendable {
    /// The name clients call the command with, in snake case.
    public var name: String

    /// What the command does, written for the agents and people that call it.
    public var summary: String

    /// The parameters of the command's arguments object.
    public var parameters: [Parameter]

    /// Typical uses of the command, to show agents and people how to call it.
    public var examples: [Example]

    /// The parameter names clients use for their own options, such as the `hammer` tool's `--output`.
    public static let reservedParameterNames: Set<String> = ["output", "port"]

    /// Creates a command descriptor.
    ///
    /// - parameter name:       The name clients call the command with, in snake case.
    /// - parameter summary:    What the command does.
    /// - parameter parameters: The parameters of the command's arguments object.
    /// - parameter examples:   Typical uses of the command.
    public init(name: String, summary: String, parameters: [Parameter] = [], examples: [Example] = []) {
        self.name = name
        self.summary = summary
        self.parameters = parameters
        self.examples = examples
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case summary
        case parameters
        case examples
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.summary = try container.decode(String.self, forKey: .summary)
        self.parameters = try container.decodeIfPresent([Parameter].self, forKey: .parameters) ?? []
        self.examples = try container.decodeIfPresent([Example].self, forKey: .examples) ?? []
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
    /// A typical use of a command.
    public struct Example: Codable, Equatable, Sendable {
        /// What the example does.
        public var summary: String

        /// The arguments object.
        public var arguments: [String: JSONValue]

        /// Creates an example.
        ///
        /// - parameter summary:   What the example does.
        /// - parameter arguments: The arguments object.
        public init(_ summary: String, _ arguments: [String: JSONValue] = [:]) {
            self.summary = summary
            self.arguments = arguments
        }
    }

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
    ///
    /// Clients decode a type they don't know as `json`, so apps can use newer types than their clients.
    public enum ParameterType: Codable, Equatable, Sendable {
        case string
        case integer
        case number
        case boolean
        case stringList
        case choice([String])

        /// Any JSON value, such as an object for a frame or a value for a property of any type.
        case json

        private enum CodingKeys: String, CodingKey {
            case type
            case values
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            switch try container.decode(String.self, forKey: .type) {
            case "string":
                self = .string
            case "integer":
                self = .integer
            case "number":
                self = .number
            case "boolean":
                self = .boolean
            case "stringList":
                self = .stringList
            case "choice":
                self = .choice(try container.decode([String].self, forKey: .values))
            default:
                self = .json
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(self.name, forKey: .type)
            if case .choice(let values) = self {
                try container.encode(values, forKey: .values)
            }
        }

        private var name: String {
            switch self {
            case .string:
                return "string"
            case .integer:
                return "integer"
            case .number:
                return "number"
            case .boolean:
                return "boolean"
            case .stringList:
                return "stringList"
            case .choice:
                return "choice"
            case .json:
                return "json"
            }
        }

        var schema: [String: JSONValue] {
            switch self {
            case .string:
                return ["type": "string"]
            case .integer:
                return ["type": "integer"]
            case .number:
                return ["type": "number"]
            case .boolean:
                return ["type": "boolean"]
            case .stringList:
                return ["type": "array", "items": ["type": "string"]]
            case .choice(let values):
                return ["type": "string", "enum": .array(values.map(JSONValue.string))]
            case .json:
                return [:]
            }
        }
    }
}
