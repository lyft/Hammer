import HammerAgentCore

/// The commands the Android system driver runs, in the same language as the agent's commands.
enum AndroidSystemCommands {
    static let traitNames = ["button", "image", "staticText", "toggleButton", "selected", "notEnabled"]

    static let elementParameters: [CommandDescriptor.Parameter] = [
        .init("identifier", .string, "The resource id name of the element, such as permission_allow_button."),
        .init("label", .string, "The content description of the element, or its text."),
        .init("value", .string, "The text of a text field, or 1 or 0 for a checked or unchecked switch."),
        .init("traits", .stringList, "Traits the element must have: \(traitNames.joined(separator: ", "))."),
    ]

    static let targetParameters: [CommandDescriptor.Parameter] = elementParameters + [
        .init("x", .number, "The x coordinate in screen dp, instead of an element."),
        .init("y", .number, "The y coordinate in screen dp, instead of an element."),
    ]

    static let describe = CommandDescriptor(
        name: "describe",
        summary: """
            Returns the accessibility nodes of every window on the device's screen, back to front, \
            including system UI such as permission dialogs, the status bar, the notification shade and \
            the home screen, with their identifier, label, value, traits and frame in screen dp.
            """,
        examples: [
            .init("See the buttons of a permission dialog"),
        ]
    )

    static let tap = CommandDescriptor(
        name: "tap",
        summary: """
            Taps an element or a point anywhere on the device's screen, such as a permission dialog's \
            button. Elements match every identifier, label, value and traits given.
            """,
        parameters: targetParameters,
        examples: [
            .init("Allow a permission dialog", ["identifier": "permission_allow_foreground_only_button"]),
            .init("Tap a point", ["x": 200, "y": 500]),
        ]
    )

    static let swipe = CommandDescriptor(
        name: "swipe",
        summary: "Swipes over an element or a point anywhere on the device's screen.",
        parameters: targetParameters + [
            .init("direction", .choice(BuiltinCommands.swipeDirections), "The direction the finger moves.",
                  isRequired: true),
            .init("distance", .number, "The dp the finger moves. Defaults to 200."),
            .init("duration", .number, "The seconds the swipe takes. Defaults to 0.2."),
        ],
        examples: [
            .init("Scroll the notification shade", ["x": 200, "y": 600, "direction": "up"]),
        ]
    )

    static let edgeSwipe = CommandDescriptor(
        name: "edge_swipe",
        summary: """
            Swipes from the edge of the screen, for the system's gestures: down from the top for the \
            notification shade, and with gesture navigation up from the bottom to go home and right from \
            the left edge to go back. press_key with deviceHome or deviceBack works with any navigation.
            """,
        parameters: [
            .init("direction", .choice(BuiltinCommands.swipeDirections),
                  "The direction the finger moves, starting from the opposite edge.", isRequired: true),
            .init("distance", .number, "The dp the finger moves. Defaults to 200."),
            .init("duration", .number, "The seconds the swipe takes. Defaults to 0.2."),
        ],
        examples: [
            .init("Open the notification shade", ["direction": "down", "distance": 400]),
        ]
    )

    static let typeText = CommandDescriptor(
        name: "type_text",
        summary: """
            Types printable ASCII text into the focused field, such as a system dialog's. Pass an element \
            to tap it first.
            """,
        parameters: [.init("text", .string, "The text to type.", isRequired: true)] + targetParameters,
        examples: [
            .init("Type a Wi-Fi password", ["identifier": "password", "text": "hunter2"]),
        ]
    )

    static let pressKey = CommandDescriptor(
        name: "press_key",
        summary: "Presses a key on the device, such as its back or home button.",
        parameters: [
            .init("key", .string, """
                The key: deviceBack, deviceHome or appSwitch for the device's buttons, a character, or a \
                keyboard key name such as returnOrEnter, escape, deleteOrBackspace, tab, home or arrowUp.
                """, isRequired: true),
        ],
        examples: [
            .init("Go to the home screen", ["key": "deviceHome"]),
            .init("Go back", ["key": "deviceBack"]),
        ]
    )

    static let screenshot = CommandDescriptor(
        name: "screenshot",
        summary: """
            Returns a PNG image of the device's whole screen, including system UI and the surfaces of maps \
            and videos, or of the area of one element.
            """,
        parameters: elementParameters + [
            .init("scale", .number, "The pixels per dp. Defaults to 1."),
        ],
        examples: [
            .init("See the screen"),
            .init("Capture it at the device's resolution", ["scale": 3]),
        ]
    )

    static let all = [describe, tap, swipe, edgeSwipe, typeText, pressKey, screenshot]

    /// `input keyevent` codes for Hammer's `KeyboardKey` names, plus the device's own buttons, named like the
    /// app agent's `deviceBack`.
    static let keyCodes: [String: String] = {
        var codes = [
            "deviceBack": "BACK", "deviceHome": "HOME", "appSwitch": "APP_SWITCH", "home": "MOVE_HOME",
            "returnOrEnter": "ENTER",
            "escape": "ESCAPE", "deleteOrBackspace": "DEL", "deleteForward": "FORWARD_DEL", "tab": "TAB",
            "spacebar": "SPACE", "hyphen": "MINUS", "equalSign": "EQUALS", "openBracket": "LEFT_BRACKET",
            "closeBracket": "RIGHT_BRACKET", "backslash": "BACKSLASH", "semicolon": "SEMICOLON",
            "quote": "APOSTROPHE", "graveAccentAndTilde": "GRAVE", "comma": "COMMA", "period": "PERIOD",
            "slash": "SLASH", "capsLock": "CAPS_LOCK", "printScreen": "SYSRQ", "insert": "INSERT",
            "end": "MOVE_END", "pageUp": "PAGE_UP", "pageDown": "PAGE_DOWN", "arrowRight": "DPAD_RIGHT",
            "arrowLeft": "DPAD_LEFT", "arrowDown": "DPAD_DOWN", "arrowUp": "DPAD_UP", "numLock": "NUM_LOCK",
            "leftControl": "CTRL_LEFT", "leftShift": "SHIFT_LEFT", "leftAlt": "ALT_LEFT",
            "leftGUI": "META_LEFT",
            "rightControl": "CTRL_RIGHT", "rightShift": "SHIFT_RIGHT", "rightAlt": "ALT_RIGHT",
            "rightGUI": "META_RIGHT",
        ]
        for letter in "ABCDEFGHIJKLMNOPQRSTUVWXYZ" {
            codes["letter\(letter)"] = "\(letter)"
        }
        for digit in 0...9 {
            codes["number\(digit)"] = "\(digit)"
        }
        for number in 1...12 {
            codes["functionF\(number)"] = "F\(number)"
        }
        return codes.mapValues { "KEYCODE_\($0)" }
    }()
}
