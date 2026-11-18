@testable import HammerCLI
import Testing

struct CLIOptionsTests {
    @Test
    func androidOptionsAnywhere() throws {
        var arguments = [
            "tap", "--android", "--label", "OK", "--serial", "emulator-5554", "--app-id=com.example",
        ]
        let options = try CLIOptions.extract(from: &arguments)

        #expect(options == CLIOptions(android: true, serial: "emulator-5554", appID: "com.example"))
        #expect(options.platform == .android)
        #expect(arguments == ["tap", "--label", "OK"])
    }

    @Test
    func serialWithoutAndroidIsTheCommands() throws {
        var arguments = ["pair", "--serial", "ABC123"]
        let options = try CLIOptions.extract(from: &arguments)

        #expect(options == CLIOptions())
        #expect(arguments == ["pair", "--serial", "ABC123"])
    }

    @Test
    func androidFalseLeavesTheSerialToTheCommand() throws {
        var arguments = ["pair", "--android=false", "--serial", "ABC123"]
        let options = try CLIOptions.extract(from: &arguments)

        #expect(options.platform == .iOS)
        #expect(arguments == ["pair", "--serial", "ABC123"])
    }

    @Test
    func emptyArgumentsAreTheCommands() throws {
        var arguments = ["tap", "--label", "", "", "--android"]
        let options = try CLIOptions.extract(from: &arguments)

        #expect(options.platform == .android)
        #expect(arguments == ["tap", "--label", "", ""])
    }

    @Test
    func optionLikeValueOfABuiltinCommandIsTheCommands() throws {
        var arguments = ["type-text", "--text", "--android", "--system", "--x", "--port"]
        let options = try CLIOptions.extract(from: &arguments)

        #expect(options == CLIOptions(system: true))
        #expect(options.platform == .iOS)
        #expect(arguments == ["type-text", "--text", "--android", "--x", "--port"])
    }

    @Test
    func androidAfterABooleanOptionIsTheTools() throws {
        var arguments = ["describe", "--all", "--android"]
        let options = try CLIOptions.extract(from: &arguments)

        #expect(options.platform == .android)
        #expect(arguments == ["describe", "--all"])
    }

    @Test
    func iOSOptions() throws {
        var arguments = ["describe", "--port", "9000", "--system", "--udid", "ABC", "--output", "out.json"]
        let options = try CLIOptions.extract(from: &arguments)

        #expect(options == CLIOptions(port: 9000, outputPath: "out.json", system: true, udid: "ABC"))
        #expect(arguments == ["describe"])
    }

    @Test(arguments: [
        (["describe", "--android", "--port", "9000"], "--port doesn't apply with --android"),
        (["describe", "--android", "--udid", "ABC"],
         "--udid picks a simulator, which doesn't apply with --android"),
        (["tap", "--android", "--system", "--app-id", "com.example"],
         "--app-id doesn't apply with --system, which drives the whole screen"),
        (["describe", "--system=maybe"], "Invalid value \"maybe\" for --system, expected true or false"),
        (["describe", "--output"], "Missing value for --output"),
        (["describe", "--port", "99999"], "Invalid port \"99999\", expected a number up to 65535"),
    ])
    func rejectsOptionsThatDontFit(arguments: [String], message: String) {
        var arguments = arguments
        let error = #expect(throws: UsageError.self) { try CLIOptions.extract(from: &arguments) }
        #expect(error?.description == message)
    }
}
