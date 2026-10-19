import Foundation
import os

// Tests set this from any context, such as a nonisolated `setUp`
private let kSettings = OSAllocatedUnfairLock(initialState: EventGenerator.Settings())

extension EventGenerator {
    /// The settings each new event generator starts with.
    nonisolated public static var settings: Settings {
        get { kSettings.withLock { $0 } }
        set { kSettings.withLock { $0 = newValue } }
    }

    /// Setting values for event generators
    ///
    /// Timeouts leave out the time the main thread is stalled without running, such as on an overloaded CI
    /// machine, so they only count the time the app had to respond.
    public struct Settings: Sendable {
        /// The delay to wait after activating the accessibility engine.
        public var accessibilityActivateDelay: TimeInterval = 0.02

        /// The delay to wait after activating the accessibility engine for the first time in a simulator.
        public var accessibilityActivateFirstTimeDelay: TimeInterval = 5.0

        /// The accessibility engine is required for finding accessibility labels. We proactively enable it
        /// to avoid issues with the first test case that uses it.
        public var forceActivateAccessibilityEngine: Bool = true

        /// If we should wait for animations to complete when an event generator is created.
        public var waitForAnimations: Bool = false

        /// If we should wait for a frame to complete rendering when an event generator is created.
        public var waitForFrameRender: Bool = true

        /// The maximum time to wait for the window to be ready when an event generator is created.
        public var windowReadyTimeout: TimeInterval = 3

        /// The maximum time to wait for UIKit to process each generated event.
        public var eventProcessingTimeout: TimeInterval = 5

        /// The maximum time the waiting methods wait when they are not given a timeout.
        public var waitTimeout: TimeInterval = 3
    }
}
