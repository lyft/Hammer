import Foundation

/// The commands every agent runs, so clients can describe them before the app is running.
public enum BuiltinCommands {
    /// The parameters that pick what a command acts on: an element, a point, or the window's center.
    ///
    /// - parameter prefix: The prefix of the parameter names, for commands that take two targets.
    /// - parameter role:   What the target is for, used in the summaries.
    ///
    /// - returns: The parameters.
    public static func targetParameters(prefix: String = "", role: String = "element")
        -> [CommandDescriptor.Parameter]
    {
        return [
            .init(prefix + "identifier", .string, "The accessibility identifier of the \(role)."),
            .init(prefix + "label", .string, "The accessibility label of the \(role)."),
            .init(prefix + "value", .string, "The accessibility value of the \(role)."),
            .init(prefix + "traits", .stringList,
                  "Accessibility traits the \(role) must have, such as button, header or selected."),
            .init(prefix + "x", .number, "The x coordinate in window points, instead of an element."),
            .init(prefix + "y", .number, "The y coordinate in window points, instead of an element."),
        ]
    }

    public static let swipeDirections = ["up", "down", "left", "right"]

    public static let describe = CommandDescriptor(
        name: "describe",
        summary: """
            Returns the tree of visible views and accessibility elements in the key window, with their \
            identifier, label, value, traits, frame in window points and whether touches reach them. \
            Containers without accessibility information are left out unless `all` is set.
            """,
        parameters: [
            .init("all", .boolean, "Include every visible view, even without accessibility information."),
        ]
    )

    public static let tap = CommandDescriptor(
        name: "tap",
        summary: """
            Taps an element or a point. Elements match every identifier, label, value and traits given.
            """,
        parameters: targetParameters() + [
            .init("count", .integer, "The number of taps, 2 for a double tap. Defaults to 1."),
        ]
    )

    public static let longPress = CommandDescriptor(
        name: "long_press",
        summary: "Touches an element or a point and holds it.",
        parameters: targetParameters() + [
            .init("duration", .number, "The seconds to hold. Defaults to 2."),
        ]
    )

    public static let swipe = CommandDescriptor(
        name: "swipe",
        summary: """
            Swipes over an element or a point, such as to scroll. Swiping up scrolls the content down.
            """,
        parameters: targetParameters() + [
            .init("direction", .choice(swipeDirections), "The direction the finger moves.",
                  isRequired: true),
            .init("distance", .number, "The points the finger moves. Defaults to 200."),
            .init("duration", .number, "The seconds the swipe takes. Defaults to 0.2."),
        ]
    )

    public static let edgeSwipe = CommandDescriptor(
        name: "edge_swipe",
        summary: """
            Swipes from the edge of the screen, such as right from the left edge to go back.
            """,
        parameters: [
            .init("direction", .choice(swipeDirections),
                  "The direction the finger moves, starting from the opposite edge.", isRequired: true),
            .init("distance", .number, "The points the finger moves. Defaults to 200."),
            .init("duration", .number, "The seconds the swipe takes. Defaults to 0.2."),
        ]
    )

    public static let drag = CommandDescriptor(
        name: "drag",
        summary: "Touches an element or a point, moves the finger to another one and lifts it.",
        parameters: targetParameters(role: "element to start from")
            + targetParameters(prefix: "to_", role: "element to end at")
            + [.init("duration", .number, "The seconds the drag takes. Defaults to 0.5.")]
    )

    public static let typeText = CommandDescriptor(
        name: "type_text",
        summary: """
            Types text with the hardware keyboard into the focused field. Pass an element to tap it first.
            """,
        parameters: [.init("text", .string, "The text to type.", isRequired: true)] + targetParameters()
    )

    public static let pressKey = CommandDescriptor(
        name: "press_key",
        summary: "Presses a hardware keyboard key.",
        parameters: [
            .init("key", .string, """
                The key: a character, or a key name such as returnOrEnter, escape, deleteOrBackspace, \
                tab or arrowUp.
                """, isRequired: true),
        ]
    )

    public static let waitFor = CommandDescriptor(
        name: "wait_for",
        summary: "Waits until an element exists, is visible, is hittable or is gone.",
        parameters: targetParameters() + [
            .init("condition", .choice(["exists", "visible", "hittable", "gone"]),
                  "What to wait for. Defaults to hittable."),
            .init("timeout", .number, "The seconds to wait. Defaults to 10."),
        ]
    )

    public static let waitForIdle = CommandDescriptor(
        name: "wait_for_idle",
        summary: "Waits until the key window has no running animations.",
        parameters: [
            .init("timeout", .number, "The seconds to wait. Defaults to 10."),
        ]
    )

    public static let screenshot = CommandDescriptor(
        name: "screenshot",
        summary: "Returns a PNG image of the windows of the app's foreground scene.",
        parameters: [
            .init("scale", .number, "The pixels per point. Defaults to 1."),
        ]
    )

    /// Every builtin command.
    public static let all = [
        describe, tap, longPress, swipe, edgeSwipe, drag, typeText, pressKey, waitFor, waitForIdle,
        screenshot,
    ]
}
