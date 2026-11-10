package com.lyft.hammer.agent.core

import com.lyft.hammer.agent.CommandDescriptor
import com.lyft.hammer.agent.CommandDescriptor.Example
import com.lyft.hammer.agent.CommandDescriptor.Parameter
import com.lyft.hammer.agent.CommandDescriptor.ParameterType
import com.lyft.hammer.agent.JsonValue

/**
 * The descriptors of the commands the Android agent runs. Mirrors `BuiltinCommands.Android` in Hammer's
 * `HammerAgentCore`, which is the source of truth for names, parameters and examples.
 */
internal object BuiltinCommands {

    val SWIPE_DIRECTIONS = listOf("up", "down", "left", "right")

    /** The parameters that pick what a command acts on: an element, a point, or the window's center. */
    fun targetParameters(prefix: String = "", role: String = "element"): List<Parameter> = elementParameters(prefix, role) + listOf(
        Parameter(prefix + "x", ParameterType.NumberValue, "The x coordinate in screen dp, instead of an element."),
        Parameter(prefix + "y", ParameterType.NumberValue, "The y coordinate in screen dp, instead of an element."),
    )

    /** [targetParameters] without the point, for commands where a point makes no sense. */
    fun elementParameters(prefix: String = "", role: String = "element"): List<Parameter> = listOf(
        Parameter(prefix + "ref", ParameterType.StringValue, "The ref of the $role from describe."),
        Parameter(prefix + "identifier", ParameterType.StringValue, "The resource id name of the $role's View, or its Compose test tag."),
        Parameter(prefix + "label", ParameterType.StringValue, "The content description of the $role, or its text."),
        Parameter(prefix + "value", ParameterType.StringValue, "The text of a text field, or the state of the $role."),
        Parameter(
            prefix + "traits",
            ParameterType.StringList,
            "Traits the $role must have, such as button, header or selected.",
        ),
    )

    val describe = CommandDescriptor(
        name = "describe",
        summary = "Returns the tree of visible Views and Jetpack Compose semantics nodes in the app's windows, " +
            "with their identifier, label, value, traits, frame in screen dp and whether touches reach " +
            "them. Each has a ref, such as e12, that other commands take to target it. Containers " +
            "without accessibility information are left out unless `all` is set.",
        parameters = listOf(
            Parameter("all", ParameterType.BooleanValue, "Include every visible view, even without accessibility information."),
        ),
        examples = listOf(
            Example("List the elements on screen"),
            Example("Include every view, such as to find one without accessibility information", mapOf("all" to JsonValue.Bool(true))),
        ),
    )

    val tap = CommandDescriptor(
        name = "tap",
        summary = "Taps an element or a point. Elements match every identifier, label, value and traits given.",
        parameters = targetParameters() + Parameter("count", ParameterType.IntegerValue, "The number of taps, 2 for a double tap. Defaults to 1."),
        examples = listOf(
            Example("Tap the element with an accessibility identifier", mapOf("identifier" to JsonValue.String("sign_in"))),
            Example(
                "Tap the button labeled Continue",
                mapOf("label" to JsonValue.String("Continue"), "traits" to JsonValue.Array(JsonValue.String("button"))),
            ),
            Example("Tap an element from describe", mapOf("ref" to JsonValue.String("e12"))),
            Example(
                "Double tap a point",
                mapOf("x" to JsonValue.Number(120), "y" to JsonValue.Number(340), "count" to JsonValue.Number(2)),
            ),
        ),
    )

    val longPress = CommandDescriptor(
        name = "long_press",
        summary = "Touches an element or a point and holds it.",
        parameters = targetParameters() + Parameter("duration", ParameterType.NumberValue, "The seconds to hold. Defaults to 2."),
        examples = listOf(
            Example(
                "Long press a cell to open its menu",
                mapOf("label" to JsonValue.String("Inbox"), "duration" to JsonValue.Number(1)),
            ),
        ),
    )

    val swipe = CommandDescriptor(
        name = "swipe",
        summary = "Swipes over an element or a point, such as to scroll. Swiping up scrolls the content down.",
        parameters = targetParameters() + listOf(
            Parameter("direction", ParameterType.Choice(SWIPE_DIRECTIONS), "The direction the finger moves.", isRequired = true),
            Parameter("distance", ParameterType.NumberValue, "The dp the finger moves. Defaults to 200."),
            Parameter("duration", ParameterType.NumberValue, "The seconds the swipe takes. Defaults to 0.2."),
        ),
        examples = listOf(
            Example(
                "Scroll a list down to reveal more rows",
                mapOf("identifier" to JsonValue.String("results"), "direction" to JsonValue.String("up")),
            ),
            Example(
                "Swipe a cell left to show its actions",
                mapOf("label" to JsonValue.String("Inbox"), "direction" to JsonValue.String("left")),
            ),
        ),
    )

    val edgeSwipe = CommandDescriptor(
        name = "edge_swipe",
        summary = "Swipes from the edge of the app's window, such as right from the left edge to open a drawer. " +
            "The system's back and home gestures are outside the app: press_key with deviceBack goes back.",
        parameters = listOf(
            Parameter(
                "direction",
                ParameterType.Choice(SWIPE_DIRECTIONS),
                "The direction the finger moves, starting from the opposite edge.",
                isRequired = true,
            ),
            Parameter("distance", ParameterType.NumberValue, "The dp the finger moves. Defaults to 200."),
            Parameter("duration", ParameterType.NumberValue, "The seconds the swipe takes. Defaults to 0.2."),
        ),
        examples = listOf(Example("Open a navigation drawer", mapOf("direction" to JsonValue.String("right")))),
    )

    val drag = CommandDescriptor(
        name = "drag",
        summary = "Touches an element or a point, moves the finger to another one and lifts it.",
        parameters = targetParameters(role = "element to start from") +
            targetParameters(prefix = "to_", role = "element to end at") +
            Parameter("duration", ParameterType.NumberValue, "The seconds the drag takes. Defaults to 0.5."),
        examples = listOf(
            Example(
                "Move a slider's thumb to a point",
                mapOf("identifier" to JsonValue.String("volume"), "to_x" to JsonValue.Number(300), "to_y" to JsonValue.Number(420)),
            ),
            Example(
                "Drag a row onto another one",
                mapOf("ref" to JsonValue.String("e4"), "to_ref" to JsonValue.String("e9"), "duration" to JsonValue.Number(1)),
            ),
        ),
    )

    val typeText = CommandDescriptor(
        name = "type_text",
        summary = "Types text with the hardware keyboard into the focused field. Pass an element to tap it first.",
        parameters = listOf(Parameter("text", ParameterType.StringValue, "The text to type.", isRequired = true)) + targetParameters(),
        examples = listOf(
            Example(
                "Tap a field and type into it",
                mapOf("identifier" to JsonValue.String("email"), "text" to JsonValue.String("me@example.com")),
            ),
            Example("Type into the field that is already focused", mapOf("text" to JsonValue.String("hello"))),
        ),
    )

    val pressKey = CommandDescriptor(
        name = "press_key",
        summary = "Presses a hardware keyboard key, or the device's back button.",
        parameters = listOf(
            Parameter(
                "key",
                ParameterType.StringValue,
                "The key: a character, a key name such as returnOrEnter, escape, deleteOrBackspace, tab or arrowUp, " +
                    "or deviceBack to go back like the back button.",
                isRequired = true,
            ),
        ),
        examples = listOf(
            Example("Submit the focused field", mapOf("key" to JsonValue.String("returnOrEnter"))),
            Example("Go back, such as to close a screen or a dialog", mapOf("key" to JsonValue.String("deviceBack"))),
        ),
    )

    val waitFor = CommandDescriptor(
        name = "wait_for",
        summary = "Waits until an element exists, is visible, is hittable or is gone.",
        parameters = targetParameters() + listOf(
            Parameter(
                "condition",
                ParameterType.Choice(listOf("exists", "visible", "hittable", "gone")),
                "What to wait for. Defaults to hittable.",
            ),
            Parameter("timeout", ParameterType.NumberValue, "The seconds to wait. Defaults to 10."),
        ),
        examples = listOf(
            Example(
                "Wait for the next screen after a tap",
                mapOf("identifier" to JsonValue.String("home_title"), "condition" to JsonValue.String("visible")),
            ),
            Example(
                "Wait for a spinner to go away",
                mapOf("identifier" to JsonValue.String("loading"), "condition" to JsonValue.String("gone")),
            ),
        ),
    )

    val waitForIdle = CommandDescriptor(
        name = "wait_for_idle",
        summary = "Waits until the app draws no frames and its main thread has nothing queued.",
        parameters = listOf(Parameter("timeout", ParameterType.NumberValue, "The seconds to wait. Defaults to 10.")),
        examples = listOf(Example("Wait for a transition to finish before describing the screen")),
    )

    val screenshot = CommandDescriptor(
        name = "screenshot",
        summary = "Returns a PNG image of the app's windows, or of the area of one element.",
        parameters = elementParameters(role = "element to capture, or none for the screen") +
            Parameter("scale", ParameterType.NumberValue, "The pixels per dp. Defaults to 1."),
        examples = listOf(
            Example("See the screen"),
            Example("Capture it at a typical device's resolution", mapOf("scale" to JsonValue.Number(3))),
            Example("Capture one element", mapOf("ref" to JsonValue.String("e3"), "scale" to JsonValue.Number(2))),
        ),
    )
}
