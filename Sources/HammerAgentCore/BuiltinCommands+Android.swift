import Foundation

extension BuiltinCommands {
    /// The built-in commands of an agent on a platform, so clients can describe them before the app runs.
    ///
    /// - parameter platform: The platform of the agent.
    ///
    /// - returns: The descriptors.
    public static func all(for platform: AgentPlatform) -> [CommandDescriptor] {
        switch platform {
        case .iOS:
            return self.all
        case .android:
            return Android.all
        }
    }

    /// The built-in commands of an Android agent. They take the same arguments as iOS, describe Views and
    /// Jetpack Compose semantics nodes, measure in screen dp, and leave out the UIKit inspection and live
    /// editing commands.
    public enum Android {
        /// The parameters that pick what a command acts on: an element, a point, or the window's center.
        ///
        /// - parameter prefix: The prefix of the parameter names, for commands that take two targets.
        /// - parameter role:   What the target is for, used in the summaries.
        ///
        /// - returns: The parameters.
        public static func targetParameters(prefix: String = "", role: String = "element")
            -> [CommandDescriptor.Parameter]
        {
            return self.elementParameters(prefix: prefix, role: role) + [
                .init(prefix + "x", .number, "The x coordinate in screen dp, instead of an element."),
                .init(prefix + "y", .number, "The y coordinate in screen dp, instead of an element."),
            ]
        }

        /// `targetParameters` without the point, for commands where a point makes no sense.
        ///
        /// - parameter prefix: The prefix of the parameter names.
        /// - parameter role:   What the element is for, used in the summaries.
        ///
        /// - returns: The parameters.
        public static func elementParameters(prefix: String = "", role: String = "element")
            -> [CommandDescriptor.Parameter]
        {
            return [
                .init(prefix + "ref", .string, "The ref of the \(role) from describe."),
                .init(prefix + "identifier", .string,
                      "The resource id name of the \(role)'s View, or its Compose test tag."),
                .init(prefix + "label", .string, "The content description of the \(role), or its text."),
                .init(prefix + "value", .string, "The text of a text field, or the state of the \(role)."),
                .init(prefix + "traits", .stringList,
                      "Traits the \(role) must have, such as button, header or selected."),
            ]
        }

        public static let describe = CommandDescriptor(
            name: "describe",
            summary: """
                Returns the tree of visible Views and Jetpack Compose semantics nodes in the app's windows, \
                with their identifier, label, value, traits, frame in screen dp and whether touches reach \
                them. Each has a ref, such as e12, that other commands take to target it. Containers \
                without accessibility information are left out unless `all` is set.
                """,
            parameters: BuiltinCommands.describe.parameters,
            examples: BuiltinCommands.describe.examples
        )

        public static let tap = CommandDescriptor(
            name: "tap",
            summary: BuiltinCommands.tap.summary,
            parameters: targetParameters() + [
                .init("count", .integer, "The number of taps, 2 for a double tap. Defaults to 1."),
            ],
            examples: BuiltinCommands.tap.examples
        )

        public static let longPress = CommandDescriptor(
            name: "long_press",
            summary: BuiltinCommands.longPress.summary,
            parameters: targetParameters() + [
                .init("duration", .number, "The seconds to hold. Defaults to 2."),
            ],
            examples: BuiltinCommands.longPress.examples
        )

        public static let swipe = CommandDescriptor(
            name: "swipe",
            summary: BuiltinCommands.swipe.summary,
            parameters: targetParameters() + swipeParameters(direction: "The direction the finger moves."),
            examples: BuiltinCommands.swipe.examples
        )

        public static let edgeSwipe = CommandDescriptor(
            name: "edge_swipe",
            summary: """
                Swipes from the edge of the app's window, such as right from the left edge to open a \
                drawer. The system's back and home gestures are outside the app: press_key with deviceBack \
                goes back.
                """,
            parameters: swipeParameters(direction: """
                The direction the finger moves, starting from the opposite edge.
                """),
            examples: [
                .init("Open a navigation drawer", ["direction": "right"]),
            ]
        )

        public static let drag = CommandDescriptor(
            name: "drag",
            summary: BuiltinCommands.drag.summary,
            parameters: targetParameters(role: "element to start from")
                + targetParameters(prefix: "to_", role: "element to end at")
                + [.init("duration", .number, "The seconds the drag takes. Defaults to 0.5.")],
            examples: BuiltinCommands.drag.examples
        )

        public static let pinch = CommandDescriptor(
            name: "pinch",
            summary: BuiltinCommands.pinch.summary,
            parameters: targetParameters() + [
                BuiltinCommands.pinchScale,
                .init("distance", .number, """
                    The dp between the fingers when they're farthest apart. Defaults to 200.
                    """),
                .init("duration", .number, "The seconds the pinch takes. Defaults to 0.5."),
            ],
            examples: BuiltinCommands.pinch.examples
        )

        public static let typeText = CommandDescriptor(
            name: "type_text",
            summary: """
                Types text into the focused text field, any characters, and presses enter for each line \
                break. Pass an element to tap it first.
                """,
            parameters: [.init("text", .string, "The text to type.", isRequired: true)] + targetParameters(),
            examples: BuiltinCommands.typeText.examples
        )

        public static let pressKey = CommandDescriptor(
            name: "press_key",
            summary: "Presses a hardware keyboard key, or the device's back button.",
            parameters: [
                .init("key", .string, """
                    The key: a character, a key name such as returnOrEnter, escape, deleteOrBackspace, tab \
                    or arrowUp, or deviceBack to go back like the back button.
                    """, isRequired: true),
            ],
            examples: [
                .init("Submit the focused field", ["key": "returnOrEnter"]),
                .init("Go back, such as to close a screen or a dialog", ["key": "deviceBack"]),
            ]
        )

        public static let waitFor = CommandDescriptor(
            name: "wait_for",
            summary: BuiltinCommands.waitFor.summary,
            parameters: targetParameters() + [
                .init("condition", .choice(["exists", "visible", "hittable", "gone"]),
                      "What to wait for. Defaults to hittable."),
                .init("timeout", .number, "The seconds to wait. Defaults to 10."),
            ],
            examples: BuiltinCommands.waitFor.examples
        )

        public static let waitForIdle = CommandDescriptor(
            name: "wait_for_idle",
            summary: """
                Waits until the app draws no frames, its main thread has nothing queued, Compose has no \
                pending work and Espresso's idling resources, if the app registers any, are idle. Work that \
                finishes later, such as a network response, needs wait_for.
                """,
            parameters: BuiltinCommands.waitForIdle.parameters,
            examples: BuiltinCommands.waitForIdle.examples
        )

        public static let screenshot = CommandDescriptor(
            name: "screenshot",
            summary: "Returns a PNG image of the app's windows, or of the area of one element.",
            parameters: elementParameters(role: "element to capture, or none for the screen") + [
                .init("scale", .number, "The pixels per dp. Defaults to 1."),
            ],
            examples: [
                .init("See the screen"),
                .init("Capture it at a typical device's resolution", ["scale": 3]),
                .init("Capture one element", ["ref": "e3", "scale": 2]),
            ]
        )

        /// Every built-in command of an Android agent.
        public static let all = [
            describe, tap, longPress, swipe, edgeSwipe, drag, pinch, typeText, pressKey, waitFor, waitForIdle,
            screenshot,
        ]

        private static func swipeParameters(direction: String) -> [CommandDescriptor.Parameter] {
            return [
                .init("direction", .choice(BuiltinCommands.swipeDirections), direction, isRequired: true),
                .init("distance", .number, "The dp the finger moves. Defaults to 200."),
                .init("duration", .number, "The seconds the swipe takes. Defaults to 0.2."),
            ]
        }
    }
}
