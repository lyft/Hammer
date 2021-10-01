import Foundation

extension EventGenerator {
    public static let keyTypeInterval: TimeInterval = 0.02

    // MARK: - Base Actions

    /// Sends a key down event.
    ///
    /// NOTE: The character is a representation for the key irrespective of any modifier keys.
    ///
    /// - parameter character: The character representing the key to press down.
    public func keyDown(_ character: Character) throws {
        let keyInfo = try KeyboardKey.fromCharacter(character)
        try self.keyDown(keyInfo.key)
    }

    /// Sends a key down event.
    ///
    /// - parameter key: The key to press down.
    public func keyDown(_ key: KeyboardKey) throws {
        try self.sendKeyboardEvent(key: key, isKeyDown: true)
    }

    /// Sends a key up event.
    ///
    /// NOTE: The character is a representation for the key irrespective of any modifier keys.
    ///
    /// - parameter character: The character representing the key to release.
    public func keyUp(_ character: Character) throws {
        let keyInfo = try KeyboardKey.fromCharacter(character)
        try self.keyUp(keyInfo.key)
    }

    /// Sends a key up event.
    ///
    /// - parameter key: The key to release.
    public func keyUp(_ key: KeyboardKey) throws {
        try self.sendKeyboardEvent(key: key, isKeyDown: false)
    }

    // MARK: - Press Actions

    /// Sends a key press event.
    ///
    /// NOTE: The character is a representation for the key irrespective of any modifier keys. To apply
    ///       modifier keys automatically use the `keyType()` method instead.
    ///
    /// - parameter character: The character representing the key to press.
    public func keyPress(_ character: Character) throws {
        let keyInfo = try KeyboardKey.fromCharacter(character)
        try self.keyPress(keyInfo.key)
    }

    /// Sends a key press event.
    ///
    /// - parameter key: The key to press.
    public func keyPress(_ key: KeyboardKey) throws {
        try self.keyDown(key)
        try self.keyUp(key)
    }

    /// Sends a key press event a specified number times.
    ///
    /// NOTE: The character is a representation for the key irrespective of any modifier keys. To apply
    ///       modifier keys automatically use the `keyType()` method instead.
    ///
    /// - parameter character:     The character representing the key to press.
    /// - parameter numberOfTimes: The number of times to press the key.
    /// - parameter interval:      The interval between key presses.
    public func keyPress(_ character: Character, numberOfTimes: Int,
                         interval: TimeInterval = EventGenerator.keyTypeInterval) throws
    {
        let keyInfo = try KeyboardKey.fromCharacter(character)
        try self.keyPress(keyInfo.key, numberOfTimes: numberOfTimes, interval: interval)
    }

    /// Sends a key press event a specified number times.
    ///
    /// - parameter key:           The key to press.
    /// - parameter numberOfTimes: The number of times to press the key.
    /// - parameter interval:      The interval between key presses.
    public func keyPress(_ key: KeyboardKey, numberOfTimes: Int,
                         interval: TimeInterval = EventGenerator.keyTypeInterval) throws
    {
        for i in 0..<numberOfTimes {
            try self.keyPress(key)
            if i < numberOfTimes - 1 {
                try self.wait(interval)
            }
        }
    }

    // MARK: - Type Actions

    /// Types the specified character, automatically applying modifier keys if necessary.
    ///
    /// - parameter character: The character to type.
    public func keyType(_ character: Character) throws {
        let keyInfo = try KeyboardKey.fromCharacter(character)

        if keyInfo.shift {
            try self.keyDown(.leftShift)
        }

        try self.keyPress(keyInfo.key)

        if keyInfo.shift {
            try self.keyUp(.leftShift)
        }
    }

    /// Types the specified string, automatically applying modifier keys if necessary.
    ///
    /// - parameter text:     The string to type.
    /// - parameter interval: The interval between key presses.
    public func keyType(_ text: String, interval: TimeInterval = EventGenerator.keyTypeInterval) throws {
        for (index, character) in text.enumerated() {
            try self.keyType(character)
            if index < text.count - 1 {
                try self.wait(interval)
            }
        }
    }

    // MARK: - Event

    /// Sends a keyboard event.
    ///
    /// - parameter key:       The keyboard key for the event.
    /// - parameter isKeyDown: If the key is currently pressed down.
    private func sendKeyboardEvent(key: KeyboardKey, isKeyDown: Bool) throws {
        guard self.isWindowReady else {
            throw HammerError.windowIsNotReadyForInteraction
        }

        guard self.window.isKeyWindow else {
            throw HammerError.windowIsNotKey
        }

        let machTime = mach_absolute_time()

        let event = IOHID.shared.createKeyboardEvent(
            kCFAllocatorDefault, machTime,
            IOHID.Page.keyboardOrKeypad.rawValue,
            key.rawValue, isKeyDown,
            kIOHIDEventOptionNone)

        IOHID.shared.eventSetSenderID(event, self.senderId)

        try self.sendEvent(event, wait: true)

        // Key events seem to be processed a little later, so we wait for one frame
        try self.wait(0.02)
    }
}
