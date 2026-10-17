import Foundation

extension EventGenerator {
    nonisolated public static let keyTypeInterval: TimeInterval = 0.02

    // MARK: - Base Actions

    /// Sends a key down event.
    ///
    /// NOTE: The character is a representation for the key irrespective of any modifier keys.
    ///
    /// - parameter character: The character representing the key to press down.
    public func keyDown(_ character: Character) async throws {
        let keyInfo = try KeyboardKey.fromCharacter(character)
        try await self.keyDown(keyInfo.key)
    }

    /// Sends a key down event.
    ///
    /// - parameter key: The key to press down.
    public func keyDown(_ key: KeyboardKey) async throws {
        try await self.sendKeyboardEvent(key: key, isKeyDown: true, wait: true)
    }

    /// Sends a key up event.
    ///
    /// NOTE: The character is a representation for the key irrespective of any modifier keys.
    ///
    /// - parameter character: The character representing the key to release.
    public func keyUp(_ character: Character) async throws {
        let keyInfo = try KeyboardKey.fromCharacter(character)
        try await self.keyUp(keyInfo.key)
    }

    /// Sends a key up event.
    ///
    /// - parameter key: The key to release.
    public func keyUp(_ key: KeyboardKey) async throws {
        try await self.sendKeyboardEvent(key: key, isKeyDown: false, wait: true)
    }

    // MARK: - Press Actions

    /// Sends a key press event.
    ///
    /// NOTE: The character is a representation for the key irrespective of any modifier keys. To apply
    ///       modifier keys automatically use the `keyType()` method instead.
    ///
    /// - parameter character: The character representing the key to press.
    public func keyPress(_ character: Character) async throws {
        let keyInfo = try KeyboardKey.fromCharacter(character)
        try await self.keyPress(keyInfo.key)
    }

    /// Sends a key press event.
    ///
    /// - parameter key: The key to press.
    public func keyPress(_ key: KeyboardKey) async throws {
        // Sending the key up right away keeps a busy main thread from repeating the key while it is down
        try await self.sendKeyboardEvent(key: key, isKeyDown: true, wait: false)
        try await self.sendKeyboardEvent(key: key, isKeyDown: false, wait: true)
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
                         interval: TimeInterval = EventGenerator.keyTypeInterval) async throws
    {
        let keyInfo = try KeyboardKey.fromCharacter(character)
        try await self.keyPress(keyInfo.key, numberOfTimes: numberOfTimes, interval: interval)
    }

    /// Sends a key press event a specified number times.
    ///
    /// - parameter key:           The key to press.
    /// - parameter numberOfTimes: The number of times to press the key.
    /// - parameter interval:      The interval between key presses.
    public func keyPress(_ key: KeyboardKey, numberOfTimes: Int,
                         interval: TimeInterval = EventGenerator.keyTypeInterval) async throws
    {
        for i in 0..<numberOfTimes {
            try await self.keyPress(key)
            if i < numberOfTimes - 1 {
                try await self.wait(interval)
            }
        }
    }

    // MARK: - Type Actions

    /// Types the specified character, automatically applying modifier keys if necessary.
    ///
    /// - parameter character: The character to type.
    public func keyType(_ character: Character) async throws {
        let keyInfo = try KeyboardKey.fromCharacter(character)

        if keyInfo.shift {
            try await self.keyDown(.leftShift)
        }

        try await self.keyPress(keyInfo.key)

        if keyInfo.shift {
            try await self.keyUp(.leftShift)
        }
    }

    /// Types the specified string, automatically applying modifier keys if necessary.
    ///
    /// - parameter text:     The string to type.
    /// - parameter interval: The interval between key presses.
    public func keyType(_ text: String,
                        interval: TimeInterval = EventGenerator.keyTypeInterval) async throws
    {
        for (index, character) in text.enumerated() {
            try await self.keyType(character)
            if index < text.count - 1 {
                try await self.wait(interval)
            }
        }
    }

    // MARK: - Event

    /// Sends a keyboard event once the window is ready and key.
    ///
    /// - parameter key:       The keyboard key for the event.
    /// - parameter isKeyDown: If the key is currently pressed down.
    /// - parameter wait:      If we should wait until UIKit has processed the event.
    private func sendKeyboardEvent(key: KeyboardKey, isKeyDown: Bool, wait: Bool) async throws {
        try self.checkWindowIsReady()

        guard self.window.isKeyWindow else {
            throw HammerError.windowIsNotKey
        }

        // The keyboard sets up its state, such as auto capitalization, after the text input gains focus
        if isKeyDown {
            try await self.waitUntilKeyboardIsIdle()
        }

        let event = self.keyboardEvent(key: key, isKeyDown: isKeyDown)
        guard wait else {
            try self.enqueueEvent(event)
            return
        }

        try await self.sendEvent(event)

        // UIKit applies key presses, such as inserting text, in a queue after the event is delivered, and
        // reacts to the new text, such as updating auto capitalization, by the next frame
        try await self.waitUntilKeyboardIsIdle()
    }

    /// Creates a keyboard event and records the key's new state.
    ///
    /// - parameter key:       The keyboard key for the event.
    /// - parameter isKeyDown: If the key is currently pressed down.
    ///
    /// - returns: The event to send.
    func keyboardEvent(key: KeyboardKey, isKeyDown: Bool) -> IOHIDEvent {
        let event = IOHID.shared.createKeyboardEvent(
            kCFAllocatorDefault, mach_absolute_time(),
            IOHID.Page.keyboardOrKeypad.rawValue,
            key.rawValue, isKeyDown,
            kIOHIDEventOptionNone)

        IOHID.shared.eventSetSenderID(event, self.senderId)

        if isKeyDown {
            self.pressedKeys.insert(key)
        } else {
            self.pressedKeys.remove(key)
        }

        return event
    }

    /// Waits until UIKit has processed all keyboard input and rendered the result.
    ///
    /// - throws: An error if the keyboard queue is not accessible or did not finish in time.
    private func waitUntilKeyboardIsIdle() async throws {
        // Blocking the main thread on the keyboard queue deadlocks with tasks that need the main thread
        let timeout = self.settings.eventProcessingTimeout
        try await self.waitForCompletion(timeout: timeout) { complete in
            try KeyboardTaskQueue.addTask {
                FrameTracker.shared.addNextFrameListener(complete)
            }
        }
    }
}
