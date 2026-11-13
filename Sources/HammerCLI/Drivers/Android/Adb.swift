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

    /// The adb found, or nil if there is none, which running it reports.
    private let executable: URL?

    /// Finds adb in `ANDROID_HOME` or `ANDROID_SDK_ROOT`, Android Studio's default SDK on macOS or Linux, or
    /// the `PATH`.
    ///
    /// - parameter environment: The environment to read the SDK's location and the `PATH` from.
    /// - parameter home:        The user's home directory, where Android Studio puts the SDK.
    init(environment: [String: String] = ProcessInfo.processInfo.environment,
         home: String = FileManager.default.homeDirectoryForCurrentUser.path)
    {
        self.environment = environment
        let sdks = [
            environment["ANDROID_HOME"], environment["ANDROID_SDK_ROOT"], "\(home)/Library/Android/sdk",
            "\(home)/Android/Sdk",
        ]
        let installed = sdks.compactMap { $0 }.map { "\($0)/platform-tools/adb" }
        let onPath = (environment["PATH"] ?? "").split(separator: ":").map { "\($0)/adb" }
        self.executable = (installed + onPath).first { FileManager.default.isExecutableFile(atPath: $0) }
            .map { URL(filePath: $0) }
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
        guard let executable = self.executable else {
            throw ClientError.noDevice("adb was not found", hint: Self.installHint)
        }

        let process = AdbProcess(executable: executable, arguments: arguments)
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

    static let installHint = "Install the Android SDK platform tools, and set ANDROID_HOME or put adb on the PATH"
}

/// One adb process, read and waited for off the cooperative thread pool.
///
/// The call ends once adb exits, even when a process it started keeps its output open, such as the adb server
/// that `adb devices` starts, which would otherwise hold the call until the server stops.
private final class AdbProcess: @unchecked Sendable {
    struct Result {
        let status: Int32
        let stdout: Data
        let stderr: Data
        let timedOut: Bool
    }

    /// How long to keep reading output after adb exits, once none arrives.
    private static let drainIdle: TimeInterval = 0.2
    /// How long adb gets to exit after SIGTERM before SIGKILL.
    private static let killGrace: TimeInterval = 1

    private let process = Process()
    private let lock = NSLock()
    private var stdout = Data()
    private var stderr = Data()
    private var openPipes = 2
    private var lastOutput = Date()
    private var exited = false
    private var timedOut = false
    private var continuation: CheckedContinuation<Result, any Error>?

    init(executable: URL, arguments: [String]) {
        self.process.executableURL = executable
        self.process.arguments = arguments
    }

    func run(timeout: Duration) async throws -> Result {
        return try await withCheckedThrowingContinuation { continuation in
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            self.process.standardOutput = outputPipe
            self.process.standardError = errorPipe
            self.continuation = continuation
            // Read both pipes as data arrives, so a full one can't block adb while the other is read
            for (pipe, isOutput) in [(outputPipe, true), (errorPipe, false)] {
                pipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    self.lock.withLock {
                        if data.isEmpty {
                            handle.readabilityHandler = nil
                            self.openPipes -= 1
                        } else if isOutput {
                            self.stdout.append(data)
                        } else {
                            self.stderr.append(data)
                        }
                        self.lastOutput = Date()
                    }
                    self.finishIfDone()
                }
            }

            self.process.terminationHandler = { _ in
                self.lock.withLock { self.exited = true }
                self.finishIfDone()
                self.drainAfterExit()
            }

            do {
                try self.process.run()
            } catch {
                self.lock.withLock { self.continuation = nil }
                for pipe in [outputPipe, errorPipe] {
                    pipe.fileHandleForReading.readabilityHandler = nil
                }
                continuation.resume(throwing: ClientError.noDevice(
                    "Unable to run adb: \(error.localizedDescription)", hint: Adb.installHint))
                return
            }

            let seconds = Double(timeout.components.seconds) + Double(timeout.components.attoseconds) / 1e18
            DispatchQueue.global().asyncAfter(deadline: .now() + seconds) {
                guard self.process.isRunning else {
                    return
                }

                self.lock.withLock { self.timedOut = true }
                self.terminate()
            }
        }
    }

    /// Stops adb, and kills it if it doesn't stop. Only adb: a server it started is shared with other clients.
    func terminate() {
        guard self.process.isRunning else {
            return
        }

        self.process.terminate()
        let pid = self.process.processIdentifier
        DispatchQueue.global().asyncAfter(deadline: .now() + Self.killGrace) {
            if self.process.isRunning {
                kill(pid, SIGKILL)
            }
        }
    }

    /// After adb exits, waits until the pipes close or no output arrives for a moment, since a process adb
    /// started may hold them open.
    private func drainAfterExit() {
        DispatchQueue.global().asyncAfter(deadline: .now() + Self.drainIdle / 4) {
            let idle = self.lock.withLock { Date().timeIntervalSince(self.lastOutput) >= Self.drainIdle }
            if idle {
                self.finish()
            } else if self.lock.withLock({ self.continuation != nil }) {
                self.drainAfterExit()
            }
        }
    }

    private func finishIfDone() {
        let done = self.lock.withLock { self.exited && self.openPipes == 0 }
        if done {
            self.finish()
        }
    }

    private func finish() {
        let (continuation, result) = self.lock.withLock {
            defer { self.continuation = nil }
            return (self.continuation, Result(status: self.process.terminationStatus, stdout: self.stdout,
                                              stderr: self.stderr, timedOut: self.timedOut))
        }

        guard let continuation else {
            return
        }

        for pipe in [self.process.standardOutput, self.process.standardError].compactMap({ $0 as? Pipe }) {
            pipe.fileHandleForReading.readabilityHandler = nil
        }
        continuation.resume(returning: result)
    }
}

extension ClientError {
    static func noDevice(_ description: String, hint: String) -> ClientError {
        return .failed(AgentErrorBody(error: description, code: .noDevice, hint: hint))
    }
}
