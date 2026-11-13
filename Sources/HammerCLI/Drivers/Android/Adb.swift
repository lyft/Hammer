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

    static let installHint =
        "Install the Android SDK platform tools, and set ANDROID_HOME or put adb on the PATH"
}

/// One adb process, read and waited for on a thread of its own, off the cooperative thread pool.
///
/// It runs adb with `posix_spawn` and waits for it with `waitpid` rather than with `Process`, whose Linux
/// version only sees the exit once every process holding adb's descriptors exits. The call ends once adb
/// exits and its output stops, even when a process it started keeps the pipes open, such as the adb server
/// that `adb devices` starts.
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
    private static let pollMilliseconds: Int32 = 50
    private static let busyRetries = 10
    private static let busyRetryMicroseconds: useconds_t = 20_000

    private let executable: URL
    private let arguments: [String]
    private let lock = NSLock()
    private var pid: pid_t?
    private var waitStatus: Int32?
    private var cancelled = false

    init(executable: URL, arguments: [String]) {
        self.executable = executable
        self.arguments = arguments
    }

    func run(timeout: Duration) async throws -> Result {
        let seconds = Double(timeout.components.seconds) + Double(timeout.components.attoseconds) / 1e18
        return try await withCheckedThrowingContinuation { continuation in
            Thread {
                continuation.resume(with: Swift.Result { try self.runBlocking(timeout: seconds) })
            }.start()
        }
    }

    /// Stops adb, as when the caller is cancelled. Only adb: a server it started is shared with other
    /// clients.
    func terminate() {
        let pid = self.lock.withLock {
            self.cancelled = true
            return self.waitStatus == nil ? self.pid : nil
        }
        if let pid {
            kill(pid, SIGTERM)
        }
    }

    private func runBlocking(timeout: TimeInterval) throws -> Result {
        var outputPipe: [Int32] = [-1, -1]
        var errorPipe: [Int32] = [-1, -1]
        guard pipe(&outputPipe) == 0, pipe(&errorPipe) == 0 else {
            throw ClientError.noDevice("Unable to run adb: \(String(cString: strerror(errno)))",
                                       hint: Adb.installHint)
        }

        // The child gets copies on 1 and 2; these ends stay out of it and of what it starts
        for descriptor in outputPipe + errorPipe {
            _ = fcntl(descriptor, F_SETFD, FD_CLOEXEC)
        }

        let pid: pid_t
        do {
            pid = try self.spawn(output: outputPipe[1], error: errorPipe[1])
        } catch {
            (outputPipe + errorPipe).forEach { close($0) }
            throw error
        }

        close(outputPipe[1])
        close(errorPipe[1])
        let alreadyCancelled = self.lock.withLock {
            self.pid = pid
            return self.cancelled
        }
        if alreadyCancelled {
            kill(pid, SIGTERM)
        }

        Thread {
            var status: Int32 = 0
            while waitpid(pid, &status, 0) == -1 && errno == EINTR {}
            self.lock.withLock { self.waitStatus = status }
        }.start()

        let read = self.read(output: outputPipe[0], error: errorPipe[0], pid: pid, timeout: timeout)
        close(outputPipe[0])
        close(errorPipe[0])
        return read
    }

    private func spawn(output: Int32, error: Int32) throws -> pid_t {
        #if canImport(Darwin)
        var actions: posix_spawn_file_actions_t?
        #else
        var actions = posix_spawn_file_actions_t()
        #endif
        posix_spawn_file_actions_init(&actions)
        defer { posix_spawn_file_actions_destroy(&actions) }
        posix_spawn_file_actions_addopen(&actions, 0, "/dev/null", O_RDONLY, 0)
        posix_spawn_file_actions_adddup2(&actions, output, 1)
        posix_spawn_file_actions_adddup2(&actions, error, 2)

        // Only standard input, output and error reach adb, as with Process, so it and the server it may
        // start don't keep the tool's other files open
        #if canImport(Darwin)
        var attributes: posix_spawnattr_t?
        posix_spawnattr_init(&attributes)
        defer { posix_spawnattr_destroy(&attributes) }
        posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_CLOEXEC_DEFAULT))
        #else
        var attributes = posix_spawnattr_t()
        posix_spawnattr_init(&attributes)
        defer { posix_spawnattr_destroy(&attributes) }
        let open = (try? FileManager.default.contentsOfDirectory(atPath: "/proc/self/fd")) ?? []
        let inherited = open.compactMap { Int32($0) }.filter { $0 > 2 && $0 != output && $0 != error }
        for descriptor in inherited {
            posix_spawn_file_actions_addclose(&actions, descriptor)
        }
        #endif

        let argv = ([self.executable.path] + self.arguments).map { strdup($0) } + [nil]
        let environment = ProcessInfo.processInfo.environment.map { strdup("\($0.key)=\($0.value)") } + [nil]
        defer { (argv + environment).forEach { free($0) } }

        var pid: pid_t = 0
        var result = posix_spawn(&pid, self.executable.path, &actions, &attributes, argv, environment)
        // A file being written while another thread spawns is briefly busy on Linux
        for _ in 0..<Self.busyRetries where result == ETXTBSY {
            usleep(Self.busyRetryMicroseconds)
            result = posix_spawn(&pid, self.executable.path, &actions, &attributes, argv, environment)
        }
        guard result == 0 else {
            throw ClientError.noDevice("Unable to run adb: \(String(cString: strerror(result)))",
                                       hint: Adb.installHint)
        }

        return pid
    }

    /// Reads both pipes at once, so a full one can't block adb while the other is read, until adb exited and
    /// they closed or went quiet, stopping adb when it takes longer than [timeout].
    private func read(output: Int32, error: Int32, pid: pid_t, timeout: TimeInterval) -> Result {
        var data = [Data(), Data()]
        var descriptors = [
            pollfd(fd: output, events: Int16(POLLIN), revents: 0),
            pollfd(fd: error, events: Int16(POLLIN), revents: 0),
        ]
        let deadline = Date(timeIntervalSinceNow: timeout)
        var timedOut = false
        var killAt: Date?
        var lastActivity = Date()
        var exitSeen = false
        var buffer = [UInt8](repeating: 0, count: 1 << 16)
        while true {
            let status = self.lock.withLock { self.waitStatus }
            if status != nil, !exitSeen {
                exitSeen = true
                lastActivity = Date()
            }

            let open = descriptors.contains { $0.fd >= 0 }
            if let status, !open || Date().timeIntervalSince(lastActivity) >= Self.drainIdle {
                return Result(status: Self.exitCode(status), stdout: data[0], stderr: data[1],
                              timedOut: timedOut)
            }

            if status == nil {
                Self.stopIfLate(pid: pid, deadline: deadline, timedOut: &timedOut, killAt: &killAt)
            }

            guard open else {
                usleep(useconds_t(Self.pollMilliseconds) * 1000)
                continue
            }

            guard poll(&descriptors, nfds_t(descriptors.count), Self.pollMilliseconds) > 0 else {
                continue
            }

            let ready = descriptors.indices.filter { descriptors[$0].fd >= 0 && descriptors[$0].revents != 0 }
            for index in ready {
                let descriptor = descriptors[index].fd
                let count = buffer.withUnsafeMutableBytes {
                    Foundation.read(descriptor, $0.baseAddress, $0.count)
                }
                if count > 0 {
                    data[index].append(contentsOf: buffer[0..<count])
                    lastActivity = Date()
                } else if count == 0 || (errno != EINTR && errno != EAGAIN) {
                    descriptors[index].fd = -1
                }
            }
        }
    }

    /// Sends SIGTERM once [deadline] passes, then SIGKILL if adb is still running after the grace period.
    private static func stopIfLate(pid: pid_t, deadline: Date, timedOut: inout Bool, killAt: inout Date?) {
        if !timedOut, Date() >= deadline {
            timedOut = true
            kill(pid, SIGTERM)
            killAt = Date(timeIntervalSinceNow: Self.killGrace)
        } else if let due = killAt, Date() >= due {
            kill(pid, SIGKILL)
            killAt = nil
        }
    }

    /// The exit code in a `waitpid` status, or 128 plus the signal that ended adb, as shells report it.
    private static func exitCode(_ status: Int32) -> Int32 {
        let signal = status & 0x7F
        return signal == 0 ? (status >> 8) & 0xFF : 128 + signal
    }
}

extension ClientError {
    static func noDevice(_ description: String, hint: String) -> ClientError {
        return .failed(AgentErrorBody(error: description, code: .noDevice, hint: hint))
    }
}
