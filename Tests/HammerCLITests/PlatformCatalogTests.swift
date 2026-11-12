import HammerAgentCore
import Testing

struct PlatformCatalogTests {
    @Test
    func iOSReservedNamesAreUnchanged() {
        #expect(CommandDescriptor.reservedParameterNames == ["output", "port", "system", "udid"])
        #expect(CommandDescriptor.reservedParameterNames(for: .iOS)
            == CommandDescriptor.reservedParameterNames)
        #expect(CommandDescriptor.reservedParameterNames(for: .android) == [
            "output", "port", "system", "udid", "android", "serial", "app_id",
        ])
    }

    @Test
    func androidCatalogLeavesOutUIKitCommands() {
        #expect(BuiltinCommands.all(for: .android).map(\.name) == [
            "describe", "tap", "long_press", "swipe", "edge_swipe", "drag", "pinch", "type_text", "press_key",
            "wait_for", "wait_for_idle", "screenshot",
        ])
        #expect(BuiltinCommands.all(for: .iOS) == BuiltinCommands.all)
    }

    @Test
    func androidCatalogTakesTheSameArgumentsAsIOS() {
        let iOS = Dictionary(uniqueKeysWithValues: BuiltinCommands.all.map { ($0.name, $0) })
        for command in BuiltinCommands.all(for: .android) {
            #expect(command.parameters.map(\.name) == iOS[command.name]?.parameters.map(\.name),
                    "\(command.name)")
        }
    }

    @Test
    func androidCatalogMeasuresInDp() {
        let summaries = BuiltinCommands.all(for: .android)
            .flatMap { [$0.summary] + $0.parameters.map(\.summary) }

        #expect(!summaries.contains { $0.contains("points") })
        #expect(summaries.contains("The x coordinate in screen dp, instead of an element."))
    }

    @Test
    func guidesOnlyCoverTheirPlatform() {
        let iOS = AgentGuide.overview(style: .commandLine, platform: .iOS)
        let android = AgentGuide.overview(style: .commandLine, platform: .android)

        #expect(iOS.contains("## Live editing"))
        #expect(!iOS.contains("Android"))
        #expect(!iOS.contains("deviceBack"))
        #expect(android.contains("`deviceBack`"))
        #expect(android.contains("a point in screen dp"))
        #expect(!android.contains("## Live editing"))
        #expect(!android.contains("--udid"))
        #expect(!android.contains("SwiftUI"))
    }
}
