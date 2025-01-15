import Foundation

extension EventGenerator {
    /// Shared setting values for all event generators
    public static var settings = Settings()

    /// Shared setting values for all event generators
    public struct Settings {
        /// The delay to wait after activating the accessibility engine.
        public var accessibilityActivateDelay: TimeInterval = 0.02

        /// The delay to wait after activating the accessibility engine for the first time in a simulator.
        public var accessibilityActivateFirstTimeDelay: TimeInterval = 5.0

        /// The accessibility engine is required for finding accessibility labels. We proactively enable it
        /// to avoid issues with the first test case that uses it.
        public var forceActivateAccessibilityEngine: Bool = true

        /// If we should wait for animations to complete when an event generator is created.
        public var waitForAnimations: Bool = false
    }
}
