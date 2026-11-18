import Foundation

/// The platform an agent runs on, which decides its built-in commands, reserved names and guide.
public enum AgentPlatform: String, CaseIterable, Sendable {
    case iOS = "ios"
    case android
}

extension CommandDescriptor {
    /// The parameter names a client uses for its own options on a platform, so commands can't use them.
    ///
    /// Both add `android` to `reservedParameterNames`, since `hammer` reads `--android` before it knows
    /// the platform, to choose it. An Android agent also reserves `serial` and `app_id`, which `hammer
    /// --android` takes as options of its own. The iOS agent only enforces `reservedParameterNames`, which
    /// grows only in a major release, so an iOS command named `android` still registers but can't be
    /// called with `hammer`.
    ///
    /// - parameter platform: The platform of the agent.
    ///
    /// - returns: The names.
    public static func reservedParameterNames(for platform: AgentPlatform) -> Set<String> {
        switch platform {
        case .iOS:
            return self.reservedParameterNames.union(["android"])
        case .android:
            return self.reservedParameterNames.union(["android"]).union(self.androidOptionNames)
        }
    }

    /// The options `hammer` only reads with `--android`, so iOS commands can still take parameters named
    /// `serial` or `app_id`.
    public static let androidOptionNames: Set<String> = ["serial", "app_id"]
}
