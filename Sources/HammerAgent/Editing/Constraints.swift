import HammerAgentCore
import UIKit

/// A constraint in an output, with a description that reads like the constraint.
struct ConstraintOutput: Encodable {
    /// An item of a constraint, a view or a layout guide.
    struct Item: Encodable {
        let ref: String?
        let type: String
        let identifier: String?

        @MainActor
        init?(_ item: AnyObject?, in context: AgentContext) {
            switch item {
            case let view as UIView:
                let reference = ViewReference(view, in: context)
                self.ref = reference.ref
                self.type = reference.type
                self.identifier = nil
            case let guide as UILayoutGuide:
                self.ref = guide.owningView.map { ViewReference($0, in: context).ref }
                self.type = String(describing: Swift.type(of: guide))
                self.identifier = guide.identifier
            default:
                return nil
            }
        }
    }

    let ref: String
    let description: String
    let first: Item?
    let firstAttribute: String
    let relation: String
    let second: Item?
    let secondAttribute: String?
    let multiplier: Double
    let constant: Double
    let priority: Double
    let active: Bool
    let identifier: String?
    let fromAutoresizingMask: Bool

    @MainActor
    init(_ constraint: NSLayoutConstraint, in context: AgentContext) {
        self.ref = context.ref(for: constraint)
        self.first = Item(constraint.firstItem, in: context)
        self.firstAttribute = constraint.firstAttribute.name
        self.relation = constraint.relation.name
        self.second = Item(constraint.secondItem, in: context)
        self.secondAttribute = constraint.secondItem == nil ? nil : constraint.secondAttribute.name
        self.multiplier = Double(constraint.multiplier).roundedForOutput
        self.constant = Double(constraint.constant).roundedForOutput
        self.priority = Double(constraint.priority.rawValue)
        self.active = constraint.isActive
        self.identifier = constraint.identifier
        self.fromAutoresizingMask = String(describing: type(of: constraint))
            == "NSAutoresizingMaskLayoutConstraint"
        self.description = Self.description(of: constraint, first: self.first, second: self.second)
    }

    /// Describes the constraint like code, such as `e3.width == e1.width * 0.5 + 8 @750`.
    @MainActor
    private static func description(of constraint: NSLayoutConstraint, first: Item?, second: Item?)
        -> String
    {
        let multiplier = Double(constraint.multiplier).roundedForOutput
        let constant = Double(constraint.constant).roundedForOutput
        var right = ""
        if let second {
            right = "\(second.ref ?? second.type).\(constraint.secondAttribute.name)"
            right += multiplier == 1 ? "" : " * \(multiplier.formatted)"
            right += constant == 0 ? "" : (constant < 0 ? " - " : " + ") + abs(constant).formatted
        } else {
            right = constant.formatted
        }

        let priority = Double(constraint.priority.rawValue)
        let firstName = first.map { $0.ref ?? $0.type } ?? "?"
        return "\(firstName).\(constraint.firstAttribute.name) \(constraint.relation.symbol) \(right)"
            + (priority == 1000 ? "" : " @\(priority.formatted)")
    }
}

extension NSLayoutConstraint.Attribute {
    private static let named: [(String, NSLayoutConstraint.Attribute)] = [
        ("left", .left), ("right", .right), ("top", .top), ("bottom", .bottom), ("leading", .leading),
        ("trailing", .trailing), ("width", .width), ("height", .height), ("centerX", .centerX),
        ("centerY", .centerY), ("lastBaseline", .lastBaseline), ("firstBaseline", .firstBaseline),
        ("leftMargin", .leftMargin), ("rightMargin", .rightMargin), ("topMargin", .topMargin),
        ("bottomMargin", .bottomMargin), ("leadingMargin", .leadingMargin),
        ("trailingMargin", .trailingMargin),
        ("centerXWithinMargins", .centerXWithinMargins), ("centerYWithinMargins", .centerYWithinMargins),
    ]

    init?(name: String) {
        guard let attribute = Self.named.first(where: { $0.0 == name })?.1 else {
            return nil
        }

        self = attribute
    }

    var name: String {
        return Self.named.first { $0.1 == self }?.0 ?? "notAnAttribute"
    }

    /// The group of attributes it can be related to, since UIKit throws for the others.
    var kind: AttributeKind {
        switch self {
        case .width, .height:
            return .dimension
        case .leading, .trailing, .leadingMargin, .trailingMargin:
            return .directionalHorizontal
        case .left, .right, .leftMargin, .rightMargin:
            return .absoluteHorizontal
        case .centerX, .centerXWithinMargins:
            return .center
        default:
            return .vertical
        }
    }

    enum AttributeKind {
        case dimension
        case directionalHorizontal
        case absoluteHorizontal
        case center
        case vertical

        /// If attributes of the two kinds can be related.
        func isCompatible(with other: AttributeKind) -> Bool {
            switch (self, other) {
            case (.center, .directionalHorizontal), (.center, .absoluteHorizontal),
                 (.directionalHorizontal, .center), (.absoluteHorizontal, .center):
                return true
            default:
                return self == other
            }
        }
    }
}

extension NSLayoutConstraint.Relation {
    private static let named: [(String, NSLayoutConstraint.Relation)] = [
        ("equal", .equal), ("lessThanOrEqual", .lessThanOrEqual), ("greaterThanOrEqual", .greaterThanOrEqual),
    ]

    init?(name: String) {
        guard let relation = Self.named.first(where: { $0.0 == name })?.1 else {
            return nil
        }

        self = relation
    }

    var name: String {
        return Self.named.first { $0.1 == self }?.0 ?? "equal"
    }

    fileprivate var symbol: String {
        switch self {
        case .lessThanOrEqual:
            return "<="
        case .greaterThanOrEqual:
            return ">="
        default:
            return "=="
        }
    }
}

extension Double {
    /// The number without a trailing `.0`, for descriptions.
    fileprivate var formatted: String {
        return self.rounded() == self ? String(Int(self)) : String(self)
    }
}

extension NSLayoutConstraint {
    /// The views the constraint relates, using the owning view of a layout guide.
    @MainActor
    var views: [UIView] {
        return [self.firstItem, self.secondItem].compactMap { item in
            (item as? UIView) ?? (item as? UILayoutGuide)?.owningView
        }
    }

    /// Throws if activating the constraint would raise an exception since its views are not in one window.
    @MainActor
    func validateActivation() throws {
        let windows = self.views.map(\.window)
        guard let window = windows.first ?? nil, windows.allSatisfy({ $0 === window }) else {
            throw AgentError.invalidArguments(
                "The constraint's views are not in the same window, so it can't be activated",
                hint: "Relate views that are on screen together, such as a view and its superview")
        }
    }
}
