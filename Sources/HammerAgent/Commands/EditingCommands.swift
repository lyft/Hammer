import Foundation
import HammerAgentCore
import UIKit

struct SetPropertyCommand: AgentCommand {
    struct Arguments: Decodable {
        private enum CodingKeys: String, CodingKey {
            case property
            case value
        }

        let target: Target
        let property: String
        let value: JSONValue

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.target = try Target(from: decoder)
            self.property = try container.decode(String.self, forKey: .property)
            self.value = try container.decode(JSONValue.self, forKey: .value)
        }
    }

    struct Output: Encodable {
        let property: String
        let value: JSONValue
        let previous: JSONValue
    }

    let descriptor = BuiltinCommands.setProperty

    func run(_ arguments: Arguments, in context: AgentContext) async throws -> Output {
        let view = try await arguments.target.view(in: context)
        let properties = ViewProperties.properties(of: view)
        guard let property = properties.first(where: { $0.name == arguments.property }) else {
            let names = properties.map(\.name)
            let suggestion = closestMatch(to: arguments.property, in: names)
                .map { ", did you mean \($0)?" } ?? ""
            throw AgentError.invalidArguments(
                "\(type(of: view)) has no property \"\(arguments.property)\"\(suggestion)",
                hint: "Its properties are \(names.joined(separator: ", "))")
        }

        let previous = property.value(of: view)
        let undo = try property.setValue(arguments.value, of: view)
        let ref = ViewReference(view, in: context).ref
        context.changes.record(view, key: property.name, view: view,
                               summary: "\(ref).\(property.name) = \(previous.compactDescription)",
                               undo: undo)
        view.layoutWindow()
        return Output(property: property.name, value: property.value(of: view), previous: previous)
    }
}

struct SetConstraintCommand: AgentCommand {
    struct Arguments: Decodable {
        let constraint: String
        let constant: CGFloat?
        let priority: Float?
        let active: Bool?
    }

    let descriptor = BuiltinCommands.setConstraint

    func run(_ arguments: Arguments, in context: AgentContext) async throws -> ConstraintOutput {
        let constraint = try context.constraint(for: arguments.constraint)
        guard arguments.constant != nil || arguments.priority != nil || arguments.active != nil else {
            throw AgentError.invalidArguments("Nothing to change on \(arguments.constraint)",
                                              hint: "Pass any of constant, priority and active")
        }

        let priority = try arguments.priority.map(UILayoutPriority.validated)
        if arguments.active == true {
            try constraint.validateActivation()
        }

        let original = ConstraintOutput(constraint, in: context)
        let constant = constraint.constant
        let originalPriority = constraint.priority
        let isActive = constraint.isActive
        let summary = "\(original.ref) is \(original.description) again"
        context.changes.record(constraint, key: "constraint", view: constraint.views.first,
                               summary: summary) { [weak constraint] in
            constraint?.update(constant: constant, priority: originalPriority, isActive: isActive)
        }

        constraint.update(constant: arguments.constant ?? constant, priority: priority ?? originalPriority,
                          isActive: arguments.active ?? isActive)
        constraint.views.first?.layoutWindow()
        return ConstraintOutput(constraint, in: context)
    }
}

struct AddConstraintCommand: AgentCommand {
    struct Arguments: Decodable {
        private enum CodingKeys: String, CodingKey {
            case attribute
            case relation
            case toAttribute = "to_attribute"
            case multiplier
            case constant
            case priority
        }

        let target: Target
        let attribute: NSLayoutConstraint.Attribute
        let relation: NSLayoutConstraint.Relation
        let other: Target
        let otherAttribute: NSLayoutConstraint.Attribute?
        let multiplier: CGFloat?
        let constant: CGFloat
        let priority: UILayoutPriority

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            // Validation already checked the names against `BuiltinCommands.layoutAttributes`
            func attribute(_ key: CodingKeys) throws -> NSLayoutConstraint.Attribute? {
                return try container.decodeIfPresent(String.self, forKey: key)
                    .flatMap(NSLayoutConstraint.Attribute.init(name:))
            }

            self.target = try Target(from: decoder)
            self.attribute = try attribute(.attribute) ?? .notAnAttribute
            self.relation = try container.decodeIfPresent(String.self, forKey: .relation)
                .flatMap(NSLayoutConstraint.Relation.init(name:)) ?? .equal
            self.other = try Target(from: decoder, prefix: "to_")
            self.otherAttribute = try attribute(.toAttribute)
            self.multiplier = try container.decodeIfPresent(CGFloat.self, forKey: .multiplier)
            self.constant = try container.decodeIfPresent(CGFloat.self, forKey: .constant) ?? 0
            self.priority = try container.decodeIfPresent(Float.self, forKey: .priority)
                .map(UILayoutPriority.validated) ?? .required
        }
    }

    let descriptor = BuiltinCommands.addConstraint

    func run(_ arguments: Arguments, in context: AgentContext) async throws -> ConstraintOutput {
        let view = try await arguments.target.view(in: context)
        let other = arguments.other.isEmpty ? nil : try await arguments.other.view(in: context)
        let otherAttribute = try self.otherAttribute(for: arguments, relatingTo: other)

        let constraint = NSLayoutConstraint(item: view, attribute: arguments.attribute,
                                            relatedBy: arguments.relation, toItem: other,
                                            attribute: otherAttribute, multiplier: arguments.multiplier ?? 1,
                                            constant: arguments.constant)
        constraint.priority = arguments.priority
        constraint.identifier = "hammer-agent"
        try constraint.validateActivation()
        constraint.isActive = true

        let output = ConstraintOutput(constraint, in: context)
        context.changes.record(constraint, key: "added", view: view,
                               summary: "\(output.ref) \(output.description) removed") { [weak constraint] in
            constraint?.isActive = false
        }

        view.layoutWindow()
        return output
    }

    /// Returns the attribute of the other view, checking the pair so UIKit does not raise an exception.
    private func otherAttribute(for arguments: Arguments, relatingTo other: UIView?) throws
        -> NSLayoutConstraint.Attribute
    {
        let attribute = arguments.attribute
        guard other != nil else {
            if arguments.otherAttribute != nil || arguments.multiplier != nil {
                throw AgentError.invalidArguments("to_attribute and multiplier need another view",
                                                  hint: "Pass the other view with to_ref or to_identifier")
            }

            if attribute.kind != .dimension {
                throw AgentError.invalidArguments(
                    "\(attribute.name) is a position, so it can't be set to a constant",
                    hint: "Relate it to another view, such as to_ref with the superview's ref")
            }

            return .notAnAttribute
        }

        let otherAttribute = arguments.otherAttribute ?? attribute
        guard attribute.kind.isCompatible(with: otherAttribute.kind) else {
            throw AgentError.invalidArguments("\(attribute.name) can't be related to \(otherAttribute.name)",
                                              hint: """
                Relate sizes to sizes, and positions to positions on the same axis. leading and trailing \
                can't be mixed with left and right
                """)
        }

        if arguments.multiplier == 0 && attribute.kind != .dimension {
            throw AgentError.invalidArguments("A multiplier of 0 is only valid for width and height",
                                              hint: "Leave multiplier out, or use a value such as 0.5")
        }

        return otherAttribute
    }
}

struct RevertCommand: AgentCommand {
    struct Output: Encodable {
        let reverted: [String]
    }

    let descriptor = BuiltinCommands.revert

    func run(_ arguments: Target, in context: AgentContext) async throws -> Output {
        let view = arguments.isEmpty ? nil : try await arguments.view(in: context)
        let reverted = context.changes.revert(view: view)
        try await context.eventGenerator().window.layoutIfNeeded()
        return Output(reverted: reverted)
    }
}

extension NSLayoutConstraint {
    /// Changes the constraint, deactivating it around a priority change UIKit does not allow while active.
    @MainActor
    fileprivate func update(constant: CGFloat, priority: UILayoutPriority, isActive: Bool) {
        let crossesRequired = (self.priority == .required) != (priority == .required)
        if crossesRequired {
            self.isActive = false
        }

        self.constant = constant
        self.priority = priority
        self.isActive = isActive
    }
}

extension UILayoutPriority {
    fileprivate static func validated(_ value: Float) throws -> UILayoutPriority {
        guard (1...1000).contains(value) else {
            throw AgentError.invalidArguments("Invalid priority \(value), expected a number from 1 to 1000",
                                              hint: "Use 1000 for required, 750 for high and 250 for low")
        }

        return UILayoutPriority(value)
    }
}
