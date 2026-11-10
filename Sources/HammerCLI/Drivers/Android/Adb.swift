import Foundation
import HammerAgentCore

/// Runs the Android SDK's `adb`.
struct Adb: Sendable {
    /// The device adb's own commands default to, which `--serial` also defaults to.
    static let serialEnvironmentKey = "ANDROID_SERIAL"

    /// How long one adb call may take before it is stopped, such as when a device is offline.
    static let defaultTimeout: Duration = .seconds(30)

    /// The environment to read `ANDROID_SERIAL` and the SDK's location from.
    let environment: [String: String]

    private let executable: URL
    private let leadingArguments: [String]

    /// Finds adb in `ANDROID_HOME` or `ANDROID_SDK_ROOT`, Android Studio's default SDK, or the `PATH`.
    init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        self.environment = environment
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
    /// - parameter timeout:   How long adb may take.
    ///
    /// - throws: A `failed` `ClientError` with adb's error if it exits with one, `timed_out` if it takes too
    ///           long, or `no_device` if adb can't run.
    ///
    /// - returns: The standard output.
    @discardableResult
    func run(_ arguments: [String], timeout: Duration = Self.defaultTimeout) async throws -> String {
        return String(bytes: try await self.runData(arguments, timeout: timeout), encoding: .utf8) ?? ""
    }

    /// Runs adb and returns its standard output as bytes, such as an image.
    ///
    /// - parameter arguments: The arguments after `adb`.
    /// - parameter timeout:   How long adb may take.
    ///
    /// - throws: The errors of `run(_:timeout:)`.
    ///
    /// - returns: The standard output.
    func runData(_ arguments: [String], timeout: Duration = Self.defaultTimeout) async throws -> Data {
        let process = AdbProcess(executable: self.executable, arguments: self.leadingArguments + arguments)
        let result = try await withTaskCancellationHandler {
            try await process.run(timeout: timeout)
        } onCancel: {
            process.terminate()
        }

        let command = "adb \(arguments.joined(separator: " "))"
        guard !result.timedOut else {
            throw ClientError.failed(AgentErrorBody(
                error: "\(command) did not finish within \(timeout.components.seconds) seconds",
                code: .timedOut,
                hint: "Check `adb devices` lists the device as `device`, and that the device isn't frozen"))
        }

        guard result.status == 0 else {
            let output = result.stderr.isEmpty ? result.stdout : result.stderr
            let message = String(bytes: output, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            throw ClientError.failed(AgentErrorBody(error: "\(command) failed: \(message)", code: .failed))
        }

        return result.stdout
    }
}

/// One adb process, read and waited for off the cooperative thread pool.
private final class AdbProcess: @unchecked Sendable {
    struct Result {
        let status: Int32
        let stdout: Data
        let stderr: Data
        let timedOut: Bool
    }

    private let process = Process()
    private let lock = NSLock()
    private var stdout = Data()
    private var stderr = Data()
    private var timedOut = false

    init(executable: URL, arguments: [String]) {
        self.process.executableURL = executable
        self.process.arguments = arguments
    }

    func run(timeout: Duration) async throws -> Result {
        return try await withCheckedThrowingContinuation { continuation in
            let output = Pipe()
            let error = Pipe()
            self.process.standardOutput = output
            self.process.standardError = error
            let finished = DispatchGroup()
            finished.enter()
            self.process.terminationHandler = { _ in finished.leave() }
            do {
                try self.process.run()
            } catch {
                continuation.resume(throwing: ClientError.noDevice(
                    "Unable to run adb: \(error.localizedDescription)",
                    hint: """
                        Install the Android SDK platform tools, and set ANDROID_HOME or put adb on the PATH
                        """))
                return
            }

            // Read both pipes at once, so a full one can't block adb while the other is read
            for (pipe, isOutput) in [(output, true), (error, false)] {
                finished.enter()
                DispatchQueue.global().async {
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    self.lock.withLock {
                        if isOutput { self.stdout = data } else { self.stderr = data }
                    }
                    finished.leave()
                }
            }

            let seconds = Double(timeout.components.seconds) + Double(timeout.components.attoseconds) / 1e18
            DispatchQueue.global().asyncAfter(deadline: .now() + seconds) {
                guard self.process.isRunning else {
                    return
                }

                self.lock.withLock { self.timedOut = true }
                self.process.terminate()
            }

            finished.notify(queue: .global()) {
                let result = self.lock.withLock {
                    Result(status: self.process.terminationStatus, stdout: self.stdout, stderr: self.stderr,
                           timedOut: self.timedOut)
                }
                continuation.resume(returning: result)
            }
        }
    }

    func terminate() {
        if self.process.isRunning {
            self.process.terminate()
        }
    }
}

extension ClientError {
    static func noDevice(_ description: String, hint: String) -> ClientError {
        return .failed(AgentErrorBody(error: description, code: .noDevice, hint: hint))
    }
}
