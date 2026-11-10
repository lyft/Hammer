import Foundation

/// The platform an agent runs on, which decides its built-in commands, reserved names and guide.
public enum AgentPlatform: String, CaseIterable, Sendable {
    case iOS = "ios"
    case android
}

extension CommandDescriptor {
    /// The parameter names a client uses for its own options on a platform, so commands can't use them.
    ///
    /// On iOS these are `reservedParameterNames`. An Android agent also reserves `android`, `serial` and
    /// `app_id`, since `hammer --android` takes them as options of its own.
    ///
    /// - parameter platform: The platform of the agent.
    ///
    /// - returns: The names.
    public static func reservedParameterNames(for platform: AgentPlatform) -> Set<String> {
        switch platform {
        case .iOS:
            return self.reservedParameterNames
        case .android:
            return self.reservedParameterNames.union(self.androidOptionNames)
        }
    }

    /// The options `hammer` only reads with `--android`, so iOS commands can still take parameters named
    /// `serial` or `app_id`.
    public static let androidOptionNames: Set<String> = ["android", "serial", "app_id"]
}
