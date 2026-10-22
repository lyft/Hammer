import Foundation
import HammerAgentCore
import UIKit

struct HierarchyCommand: AgentCommand {
    struct Arguments: Decodable {
        private enum CodingKeys: String, CodingKey {
            case depth
        }

        let target: Target
        let depth: Int?

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.target = try Target(from: decoder)
            self.depth = try container.decodeIfPresent(Int.self, forKey: .depth)
        }
    }

    /// A view in the output, leaving out default values to keep it short.
    struct Node: Encodable {
        let ref: String
        let type: String
        let identifier: String?
        let frame: Frame
        let hidden: Bool?
        let alpha: Double?
        let viewController: String?
        let children: [Node]?
    }

    let descriptor = BuiltinCommands.hierarchy

    func run(_ arguments: Arguments, in context: AgentContext) async throws -> Node {
        if let depth = arguments.depth, depth < 0 {
            throw AgentError.invalidArguments(
                "Invalid depth \(depth), expected 0 or more",
                hint: "Use 0 for only the view, or leave it out for every level")
        }

        let root = arguments.target.isEmpty
            ? try await context.eventGenerator().window
            : try await arguments.target.view(in: context)
        context.references.removeReleased()
        return self.node(for: root, depth: arguments.depth ?? .max, in: context)
    }

    private func node(for view: UIView, depth: Int, in context: AgentContext) -> Node {
        let children = depth > 0
            ? view.subviews.map { self.node(for: $0, depth: depth - 1, in: context) }
            : []
        let reference = ViewReference(view, in: context)
        let identifier = view.accessibilityIdentifier
        return Node(ref: reference.ref, type: reference.type,
                    identifier: identifier?.isEmpty == false ? identifier : nil,
                    frame: Frame(view.frameInWindow), hidden: view.isHidden ? true : nil,
                    alpha: view.alpha < 1 ? Double(view.alpha).roundedForOutput : nil,
                    viewController: view.viewControllerType, children: children.isEmpty ? nil : children)
    }
}

struct InspectCommand: AgentCommand {
    struct Output: Encodable {
        struct Property: Encodable {
            let name: String
            let type: String
            let value: JSONValue
            let settable: Bool
            let summary: String
        }

        let ref: String
        let type: String
        let viewController: String?
        let frameInWindow: Frame
        let hasAmbiguousLayout: Bool
        let properties: [Property]
        let constraints: [ConstraintOutput]
        let superview: ViewReference?
        let subviews: [ViewReference]
    }

    let descriptor = BuiltinCommands.inspect

    func run(_ arguments: Target, in context: AgentContext) async throws -> Output {
        let view = try await arguments.view(in: context)
        context.references.removeReleased()

        let properties = ViewProperties.properties(of: view).map { property in
            Output.Property(name: property.name, type: property.typeName, value: property.value(of: view),
                            settable: property.isSettable, summary: property.summary)
        }

        var seen = Set<ObjectIdentifier>()
        let constraints = (view.constraintsAffectingLayout(for: .horizontal)
            + view.constraintsAffectingLayout(for: .vertical))
            .filter { seen.insert(ObjectIdentifier($0)).inserted }

        let reference = ViewReference(view, in: context)
        return Output(ref: reference.ref, type: reference.type, viewController: view.viewControllerType,
                      frameInWindow: Frame(view.frameInWindow), hasAmbiguousLayout: view.hasAmbiguousLayout,
                      properties: properties,
                      constraints: constraints.map { ConstraintOutput($0, in: context) },
                      superview: view.superview.map { ViewReference($0, in: context) },
                      subviews: view.subviews.map { ViewReference($0, in: context) })
    }
}
