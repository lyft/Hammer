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
                let names = UIAccessibilityTraits.allNames
                let suggestion = closestMatch(to: name, in: names).map { ", did you mean \($0)?" } ?? ""
                throw AgentError.invalidArguments("Unknown accessibility trait \"\(name)\"\(suggestion)",
                                                  hint: "The traits are \(names.joined(separator: ", "))")
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
            throw AgentError.invalidArguments(
                "Only one of \(prefix)x and \(prefix)y was passed",
                hint: "Pass both, in window points like the frames from describe")
        }

        if [self.ref != nil, self.query != nil, self.point != nil].filter({ $0 }).count > 1 {
            throw AgentError.invalidArguments("The target has more than one of a ref, a query and a point",
                                              hint: """
                Pass only one: \(prefix)ref, or any of \(prefix)identifier, \(prefix)label, \(prefix)value \
                and \(prefix)traits, or \(prefix)x and \(prefix)y
                """)
        }
    }

    /// If no target was passed, for commands where the target is optional.
    var isEmpty: Bool {
        return self.ref == nil && self.query == nil && self.point == nil
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

    /// The view to inspect or change, the topmost view at the point for a point.
    ///
    /// - parameter context: The context that resolves refs and queries.
    ///
    /// - throws: An error if the target is empty, is not found or is an element that is not a view.
    ///
    /// - returns: The view.
    @MainActor
    func view(in context: AgentContext) async throws -> UIView {
        let element: AccessibilityElement
        if let ref = self.ref {
            element = try context.element(for: ref)
        } else if let query = self.query {
            element = try await context.eventGenerator().element(matching: query)
        } else if let point = self.point {
            let window = try await context.eventGenerator().window
            guard let view = window.hitTest(point, with: nil) else {
                throw AgentError.invalidArguments("No view is at \(point.x), \(point.y)",
                                                  hint: "Pass a point inside the window, in window points")
            }

            return view
        } else {
            throw AgentError.invalidArguments("This command needs a view", hint: """
                Pass the view's ref from describe or hierarchy, any of identifier, label, value and traits, \
                or x and y for the topmost view at a point
                """)
        }

        guard let view = element.view else {
            throw AgentError.invalidArguments(
                "The element is an accessibility element, such as a SwiftUI one, not a view",
                hint: "Call hierarchy to find the UIKit view that hosts it, and target that view instead")
        }

        return view
    }

    /// The query, for commands that search for an element.
    ///
    /// - throws: An error if the target is not a query.
    func requiredQuery() throws -> AccessibilityQuery {
        guard let query = self.query else {
            throw AgentError.invalidArguments("This command needs an element to look for", hint: """
                Pass any of identifier, label, value and traits. Refs and points are not supported here \
                since the element may not exist yet
                """)
        }

        return query
    }
}
