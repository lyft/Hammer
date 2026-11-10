import Foundation
import HammerAgentCore

/// Runs the Android SDK's `adb`.
struct Adb: Sendable {
    /// The device adb's own commands default to, which `--serial` also defaults to.
    static let serialEnvironmentKey = "ANDROID_SERIAL"

    private let executable: URL
    private let leadingArguments: [String]

    /// Finds adb in `ANDROID_HOME` or `ANDROID_SDK_ROOT`, Android Studio's default SDK, or the `PATH`.
    init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let sdks = [
            environment["ANDROID_HOME"], environment["ANDROID_SDK_ROOT"], "\(home)/Library/Android/sdk",
        ]
        let installed = sdks.compactMap { $0 }.map { "\($0)/platform-tools/adb" }
            .first { FileManager.default.isExecutableFile(atPath: $0) }
        if let installed {
            self.executable = URL(filePath: installed)
            self.leadingArguments = []
        } else {
            self.executable = URL(filePath: "/usr/bin/env")
            self.leadingArguments = ["adb"]
        }
    }

    /// Runs adb and returns its standard output.
    ///
    /// - parameter arguments: The arguments after `adb`.
    ///
    /// - throws: A `no_device` `ClientError` if adb can't run or exits with an error.
    ///
    /// - returns: The standard output.
    @discardableResult
    func run(_ arguments: [String]) throws -> String {
        return String(bytes: try self.runData(arguments), encoding: .utf8) ?? ""
    }

    /// Runs adb and returns its standard output as bytes, such as an image.
    ///
    /// - parameter arguments: The arguments after `adb`.
    ///
    /// - throws: A `no_device` `ClientError` if adb can't run or exits with an error.
    ///
    /// - returns: The standard output.
    func runData(_ arguments: [String]) throws -> Data {
        let process = Process()
        process.executableURL = self.executable
        process.arguments = self.leadingArguments + arguments
        let output = Pipe()
        let error = Pipe()
        process.standardOutput = output
        process.standardError = error
        do {
            try process.run()
        } catch {
            throw ClientError.noDevice("Unable to run adb: \(error.localizedDescription)", hint: """
                Install the Android SDK platform tools, and set ANDROID_HOME or put adb on the PATH
                """)
        }

        // Read before waiting, so a full pipe can't block adb
        let stdout = output.fileHandleForReading.readDataToEndOfFile()
        let stderr = error.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let message = String(bytes: stderr, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw ClientError.noDevice("adb \(arguments.joined(separator: " ")) failed: \(message ?? "")",
                                       hint: "Check `adb devices` lists the device as `device`")
        }

        return stdout
    }
}

extension ClientError {
    static func noDevice(_ description: String, hint: String) -> ClientError {
        return .failed(AgentErrorBody(error: description, code: .noDevice, hint: hint))
    }
}
