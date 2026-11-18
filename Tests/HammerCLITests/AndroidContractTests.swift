import Foundation
@testable import HammerAgentCore
import Testing

/// Checks the files in `android/contract/` that the Android agent's tests read, so the Swift and Kotlin sides
/// describe the same commands, reserved names and error codes. Set `HAMMER_UPDATE_CONTRACT=1` to write them.
struct AndroidContractTests {
    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    private static let contract = root.appendingPathComponent("android/contract")

    @Test
    func builtinCommandsMatchTheContract() throws {
        try Self.check("builtin-commands.json", BuiltinCommands.all(for: .android))
    }

    @Test
    func reservedParameterNamesMatchTheContract() throws {
        let names = CommandDescriptor.reservedParameterNames(for: .android).sorted()
        try Self.check("reserved-parameter-names.json", names)
    }

    @Test
    func agentErrorCodesMatchTheContract() throws {
        try Self.check("error-codes.json", AgentErrorCode.agentCodes.map(\.rawValue))
    }

    @Test
    func everyErrorCodeIsAnAgentOrClientCode() throws {
        let wire = Self.root.appendingPathComponent("Sources/HammerAgentCore/AgentWire.swift")
        let source = try String(contentsOf: wire, encoding: .utf8)
        let values = source.matches(of: #/static let \w+: Self = "([a-z_]+)"/#)
            .map { String($0.output.1) }
        let listed = (AgentErrorCode.agentCodes + AgentErrorCode.clientCodes).map(\.rawValue)
        #expect(!values.isEmpty)
        #expect(Set(values) == Set(listed), "Add each new code to agentCodes or clientCodes")
        #expect(listed.count == Set(listed).count)
    }

    private static func check(_ name: String, _ value: some Encodable) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let expected = try #require(String(bytes: try encoder.encode(value), encoding: .utf8)) + "\n"
        let url = self.contract.appendingPathComponent(name)
        if ProcessInfo.processInfo.environment["HAMMER_UPDATE_CONTRACT"] == "1" {
            try FileManager.default.createDirectory(at: self.contract, withIntermediateDirectories: true)
            try expected.write(to: url, atomically: true, encoding: .utf8)
            return
        }

        let actual = try? String(contentsOf: url, encoding: .utf8)
        #expect(actual == expected, """
            android/contract/\(name) is out of date. Run HAMMER_UPDATE_CONTRACT=1 swift test --filter \
            AndroidContractTests, then update the Android agent to match
            """)
    }
}
