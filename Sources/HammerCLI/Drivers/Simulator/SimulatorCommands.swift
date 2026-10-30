import HammerAgentCore

/// The commands the simulator driver runs, in the same language as the agent's commands.
enum SimulatorCommands {
    static let traitNames = ["button", "link", "header", "image", "staticText", "searchField"]

    static let targetParameters: [CommandDescriptor.Parameter] = [
        .init("identifier", .string, "The accessibility identifier of the element."),
        .init("label", .string, "The accessibility label of the element."),
        .init("value", .string, "The accessibility value of the element."),
        .init("traits", .stringList, "Traits the element must have: \(traitNames.joined(separator: ", "))."),
        .init("x", .number, "The x coordinate in screen points, instead of an element."),
        .init("y", .number, "The y coordinate in screen points, instead of an element."),
    ]

    static let describe = CommandDescriptor(
        name: "describe",
        summary: """
            Returns the accessibility elements on the whole screen of the simulator, including system UI \
            such as permission alerts and the home screen, with their identifier, label, value, traits and \
            frame in screen points.
            """,
        examples: [
            .init("See the buttons of a permission alert"),
        ]
    )

    static let tap = CommandDescriptor(
        name: "tap",
        summary: """
            Taps an element or a point anywhere on the simulator's screen, such as a permission alert's \
            button. Elements match every identifier, label, value and traits given.
            """,
        parameters: targetParameters + [
            .init("count", .integer, "The number of taps, 2 for a double tap. Defaults to 1."),
        ],
        examples: [
            .init("Allow a permission alert", ["label": "Allow", "traits": ["button"]]),
            .init("Tap a point", ["x": 200, "y": 500]),
        ]
    )

    static let all = [describe, tap]
}
