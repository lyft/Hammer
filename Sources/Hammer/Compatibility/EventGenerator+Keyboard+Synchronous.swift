import Foundation

// Synchronous versions of the async API, for tests that are not async.
extension EventGenerator {
    public func keyDown(_ character: Character) throws {
        try self.runSynchronously { try await self.keyDown(character) }
    }

    public func keyDown(_ key: KeyboardKey) throws {
        try self.runSynchronously { try await self.keyDown(key) }
    }

    public func keyUp(_ character: Character) throws {
        try self.runSynchronously { try await self.keyUp(character) }
    }

    public func keyUp(_ key: KeyboardKey) throws {
        try self.runSynchronously { try await self.keyUp(key) }
    }

    public func keyPress(_ character: Character) throws {
        try self.runSynchronously { try await self.keyPress(character) }
    }

    public func keyPress(_ key: KeyboardKey) throws {
        try self.runSynchronously { try await self.keyPress(key) }
    }

    public func keyPress(_ character: Character, numberOfTimes: Int,
                         interval: TimeInterval = EventGenerator.keyTypeInterval) throws
    {
        try self.runSynchronously {
            try await self.keyPress(character, numberOfTimes: numberOfTimes, interval: interval)
        }
    }

    public func keyPress(_ key: KeyboardKey, numberOfTimes: Int,
                         interval: TimeInterval = EventGenerator.keyTypeInterval) throws
    {
        try self.runSynchronously {
            try await self.keyPress(key, numberOfTimes: numberOfTimes, interval: interval)
        }
    }

    public func keyType(_ character: Character) throws {
        try self.runSynchronously { try await self.keyType(character) }
    }

    public func keyType(_ text: String, interval: TimeInterval = EventGenerator.keyTypeInterval) throws {
        try self.runSynchronously { try await self.keyType(text, interval: interval) }
    }
}
