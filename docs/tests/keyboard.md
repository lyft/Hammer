# Keyboard

Keyboard methods take an explicit `KeyboardKey` object or a `Character`. Characters will be mapped to their closest keyboard key, you must wrap them with a shift key modifier if needed. This means that specifying a lowercase "a" character is equivalent to specifying an uppercase "A", this is also true for keys with symbols.

```swift
// Explicit `KeyboardKey`
try await eventGenerator.keyDown(.letterA)
try await eventGenerator.keyUp(.letterA)

// Automatic `Character` mapping
try await eventGenerator.keyDown("a")
try await eventGenerator.keyUp("a")

// Convenience key down and up events
try await eventGenerator.keyPress(.letterA)
try await eventGenerator.keyPress("a")
```

To type characters or longer strings and get automatic shift wrapping you can use the `keyType()` methods.

```swift
try await eventGenerator.keyType("This will type the string as specified, including symbols!")
```

Keys go to the first responder, so tap a text field before typing into it. When the typed text must match exactly, turn off the field's `autocorrectionType`, `spellCheckingType`, `smartQuotesType` and `smartDashesType` in the test.
