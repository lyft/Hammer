import Hammer
import UIKit

/// What a command acts on, decoded from the parameters in `BuiltinCommands.targetParameters`.
struct Target: Decodable {
    private struct Key: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }

        init(stringValue: String) {
            self.stringValue = stringValue
        }

        init?(intValue: Int) {
            return nil
        }
    }

    let ref: String?
    let query: AccessibilityQuery?
    let point: CGPoint?

    init(from decoder: Decoder) throws {
        try self.init(from: decoder, prefix: "")
    }

    /// Decodes the target from the parameters with the prefix, for commands that take two targets.
    ///
    /// - parameter decoder: The decoder of the command's arguments.
    /// - parameter prefix:  The prefix of the parameter names.
    init(from decoder: Decoder, prefix: String) throws {
        let container = try decoder.container(keyedBy: Key.self)
        func decode<T: Decodable>(_ type: T.Type, _ name: String) throws -> T? {
            return try container.decodeIfPresent(type, forKey: Key(stringValue: prefix + name))
        }

        self.ref = try decode(String.self, "ref")

        let traitNames = try decode([String].self, "traits") ?? []
        let traits = try traitNames.reduce(into: UIAccessibilityTraits()) { traits, name in
            guard let trait = UIAccessibilityTraits(name: name) else {
                throw AgentError.invalidArguments("Unknown accessibility trait \"\(name)\"")
            }

            traits.formUnion(trait)
        }

        let query = AccessibilityQuery(identifier: try decode(String.self, "identifier"),
                                       label: try decode(String.self, "label"),
                                       value: try decode(String.self, "value"), traits: traits)
        let isQueryEmpty = query.identifier == nil && query.label == nil && query.value == nil
            && query.traits.isEmpty
        self.query = isQueryEmpty ? nil : query

        switch (try decode(Double.self, "x"), try decode(Double.self, "y")) {
        case (.some(let x), .some(let y)):
            self.point = CGPoint(x: x, y: y)
        case (.none, .none):
            self.point = nil
        default:
            throw AgentError.invalidArguments("Pass both \(prefix)x and \(prefix)y")
        }

        if [self.ref != nil, self.query != nil, self.point != nil].filter({ $0 }).count > 1 {
            throw AgentError.invalidArguments("""
                Pass only one of \(prefix)ref, an element query, or \(prefix)x and \(prefix)y
                """)
        }
    }

    /// The location to send touches to, or nil for the center of the window.
    ///
    /// - parameter context: The context that resolves refs.
    ///
    /// - throws: An error if the ref is unknown.
    @MainActor
    func location(in context: AgentContext) throws -> HammerLocatable? {
        if let ref = self.ref {
            return try context.element(for: ref)
        }

        return self.query ?? self.point
    }

    /// The query, for commands that search for an element.
    ///
    /// - throws: An error if the target is not a query.
    func requiredQuery() throws -> AccessibilityQuery {
        guard let query = self.query else {
            throw AgentError.invalidArguments("Pass an identifier, label, value or traits")
        }

        return query
    }
}
