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
    }
}
