import Foundation

/// The commands that inspect and change views live, to try a fix before writing it in code.
extension BuiltinCommands {
    /// The layout attributes constraints use, by their `NSLayoutConstraint.Attribute` names.
    public static let layoutAttributes = [
        "left", "right", "top", "bottom", "leading", "trailing", "width", "height", "centerX", "centerY",
        "lastBaseline", "firstBaseline", "leftMargin", "rightMargin", "topMargin", "bottomMargin",
        "leadingMargin", "trailingMargin", "centerXWithinMargins", "centerYWithinMargins",
    ]

    public static let layoutRelations = ["equal", "lessThanOrEqual", "greaterThanOrEqual"]

    /// The parameters that pick a view, without points for commands where a point makes no sense.
    ///
    /// - parameter prefix: The prefix of the parameter names.
    /// - parameter role:   What the view is for, used in the summaries.
    ///
    /// - returns: The parameters.
    public static func elementParameters(prefix: String = "", role: String = "view")
        -> [CommandDescriptor.Parameter]
    {
        let points: Set = [prefix + "x", prefix + "y"]
        return self.targetParameters(prefix: prefix, role: role).filter { !points.contains($0.name) }
    }

    public static let hierarchy = CommandDescriptor(
        name: "hierarchy",
        summary: """
            Returns the tree of UIKit views in the key window, or under a view, including hidden ones. Each \
            node has its ref, type, frame in window points, identifier, the view controller that owns it, \
            and whether it is hidden or transparent. Use it to find views that describe leaves out, such as \
            containers and hidden views.
            """,
        parameters: elementParameters(role: "view to start from") + [
            .init("depth", .integer, "How many levels of subviews to include. Defaults to all."),
        ],
        examples: [
            .init("Export the whole hierarchy of the window"),
            .init("Show a view and two levels below it", ["ref": "e3", "depth": 2]),
        ]
    )

    public static let inspect = CommandDescriptor(
        name: "inspect",
        summary: """
            Returns a view's properties with their types and values, the constraints that lay it out with \
            their refs, its superview, subviews and view controller, and whether its layout is ambiguous. \
            Pass x and y for the topmost view at a point.
            """,
        parameters: targetParameters(role: "view"),
        examples: [
            .init("See why a label is cut off", ["identifier": "title_label"]),
            .init("Inspect the view under a point", ["x": 200, "y": 120]),
        ]
    )

    public static let setProperty = CommandDescriptor(
        name: "set_property",
        summary: """
            Changes a property of a view live, such as backgroundColor, alpha, isHidden, frame, text or \
            spacing, and lays out the window again. inspect lists each view's properties and their types. \
            Colors take hex strings like "#3366FF", names like "systemBlue" or null; rects, sizes, points \
            and insets take objects. Call revert to undo the changes.
            """,
        parameters: targetParameters(role: "view") + [
            .init("property", .string, "The property name, as inspect lists it.", isRequired: true),
            .init("to", .json, "The new value as JSON, in the property's type.", isRequired: true),
        ],
        examples: [
            .init("Try a blue background",
                  ["ref": "e3", "property": "backgroundColor", "to": "systemBlue"]),
            .init("Make a view half transparent",
                  ["identifier": "banner", "property": "alpha", "to": 0.5]),
            .init("Hide a view", ["ref": "e7", "property": "isHidden", "to": true]),
            .init("Increase a stack view's spacing", ["ref": "e2", "property": "spacing", "to": 16]),
        ]
    )

    public static let setConstraint = CommandDescriptor(
        name: "set_constraint",
        summary: """
            Changes a constraint live, by its ref from inspect, and lays out the window again. Call revert \
            to undo the changes.
            """,
        parameters: [
            .init("constraint", .string, "The constraint's ref from inspect, such as c4.", isRequired: true),
            .init("constant", .number, "The new constant."),
            .init("priority", .number, "The new priority, from 1 to 1000."),
            .init("active", .boolean, "If the constraint is active."),
        ],
        examples: [
            .init("Increase a margin", ["constraint": "c4", "constant": 24]),
            .init("Turn off a constraint to see if it causes a conflict",
                  ["constraint": "c9", "active": false]),
        ]
    )

    public static let addConstraint = CommandDescriptor(
        name: "add_constraint",
        summary: """
            Adds and activates a constraint live, between a view and another view or a constant, and lays \
            out the window again. The view's translatesAutoresizingMaskIntoConstraints is left as is. \
            Returns the constraint with its ref. Call revert to remove it.
            """,
        parameters: elementParameters(role: "view") + [
            .init("attribute", .choice(layoutAttributes), "The attribute of the view.", isRequired: true),
            .init("relation", .choice(layoutRelations), "The relation. Defaults to equal."),
        ] + elementParameters(prefix: "to_", role: "other view, or none to relate to a constant") + [
            .init("to_attribute", .choice(layoutAttributes),
                  "The attribute of the other view. Defaults to the same attribute."),
            .init("multiplier", .number, "The multiplier of the other view's attribute. Defaults to 1."),
            .init("constant", .number, "The constant. Defaults to 0."),
            .init("priority", .number, "The priority, from 1 to 1000. Defaults to 1000."),
        ],
        examples: [
            .init("Fix a view's height", ["ref": "e3", "attribute": "height", "constant": 44]),
            .init("Align a view's leading edge with another's",
                  ["ref": "e3", "attribute": "leading", "to_ref": "e1", "constant": 16]),
        ]
    )

    public static let revert = CommandDescriptor(
        name: "revert",
        summary: """
            Undoes the changes of set_property, set_constraint and add_constraint, restoring the original \
            values. Reverts every change, or only the changes of one view.
            """,
        parameters: elementParameters(role: "view to revert, or none for every change"),
        examples: [
            .init("Undo every change"),
            .init("Undo the changes to one view", ["ref": "e3"]),
        ]
    )
}
