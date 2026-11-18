import Foundation
#if canImport(Glibc)
import Glibc
#endif
import HammerAgentCore

/// The system helper: an instrumentation APK the tool embeds, installs and starts on the device, which holds
/// UiAutomation and answers the whole-screen commands in about a tenth of a second, where `uiautomator dump`
/// takes seconds. It runs until `hammer system stop` or ten idle minutes, and while it does, other tools that
/// need UiAutomation, such as uiautomator and UI tests, can't start.
struct AndroidSystemHelper: Sendable {
    /// The abstract socket the helper listens on. Mirrors `SystemServer.SOCKET_NAME`.
    static let socketName = "hammer_system"

    static let packageName = "com.lyft.hammer.system"

    /// Points the tool at another helper APK, such as one built from a checkout, instead of the embedded one.
    static let apkEnvironmentKey = "HAMMER_SYSTEM_HELPER_APK"

    /// Set to `0` to run the whole screen through uiautomator without the helper, or to `auto` to let app
    /// commands start it.
    static let enabledEnvironmentKey = "HAMMER_SYSTEM_HELPER"

    /// How long a start waits for the helper's socket.
    static let startTimeout: Duration = .seconds(10)

    let adb: Adb
    let serial: String

    /// Where this host keeps the lock and the last failed start for each device.
    var stateDirectory: URL = FileManager.default.temporaryDirectory

    /// How long a start waits for the helper's socket.
    var startWait: Duration = Self.startTimeout

    private var instrumentation: String {
        return "\(Self.packageName)/.SystemServer"
    }

    /// Why the helper can't be used, so the tool runs the command through uiautomator instead.
    struct Unavailable: Error, CustomStringConvertible {
        let description: String
    }

    /// The helper APK to install: the one `HAMMER_SYSTEM_HELPER_APK` names, or the one built into the tool.
    static func apk(environment: [String: String]) throws -> Data? {
        if let path = environment[self.apkEnvironmentKey], !path.isEmpty {
            do {
                return try Data(contentsOf: URL(filePath: path))
            } catch {
                throw Unavailable(
                    description: "\(self.apkEnvironmentKey) is \(path), which can't be read: \(error)")
            }
        }

        return SystemHelperAPK.base64.isEmpty ? nil : Data(base64Encoded: SystemHelperAPK.base64)
    }

    static func isEnabled(environment: [String: String]) -> Bool {
        return environment[self.enabledEnvironmentKey] != "0"
    }

    /// Whether commands in the app may start the helper to read what the agent can't, such as a web page:
    /// with `HAMMER_SYSTEM_HELPER=auto`. Otherwise only `--system` commands and `hammer system start` start
    /// it, since a running helper keeps UI tests and uiautomator from UiAutomation for ten idle minutes.
    static func startsForAppCommands(environment: [String: String]) -> Bool {
        return environment[self.enabledEnvironmentKey] == "auto"
    }

    /// A client for the running helper, starting it first, and installing or replacing it when the device's
    /// differs from the tool's. A start that failed in the last `failureMemory` isn't tried again unless
    /// `retryingRecentFailure`, so commands don't each wait for it.
    ///
    /// - throws: `Unavailable` when the helper can't run, such as when the tool was built without it, the
    ///           device refuses the install, another tool holds UiAutomation, or another process took the
    ///           helper's socket.
    func client(retryingRecentFailure: Bool = false) async throws -> AgentClient {
        if let client = try await self.provenClient(current: true) {
            return client
        }

        if !retryingRecentFailure, let failure = self.recentFailure() {
            throw failure
        }

        do {
            let client = try await self.withStartLock {
                // Another hammer process may have started it while this one waited
                if let client = try await self.provenClient(current: true) {
                    return client
                }

                return try await self.startFresh()
            }
            self.forgetFailure()
            return client
        } catch let error as Unavailable {
            self.remember(error)
            throw error
        }
    }

    /// A client for the helper when it is already running, without starting it, or nil when it isn't, for
    /// commands that only use it if it's there.
    ///
    /// - throws: `Unavailable` when something listens on the helper's socket that hammer can't verify.
    func runningClient() async throws -> AgentClient? {
        if let client = try await self.provenClient(current: false) {
            return client
        }

        guard try await self.isRunning() else {
            return nil
        }

        throw Unavailable(description: """
            what listens on @\(Self.socketName) didn't prove it is the system helper this hammer started. \
            Run `hammer system start --android` to restart the helper
            """)
    }

    /// A client for a running helper that proved it holds the secret of the last start, or nil. With
    /// `current`, the helper must also be the tool's version.
    private func provenClient(current: Bool) async throws -> AgentClient? {
        guard let secret = try await self.secret() else {
            return nil
        }

        let client = try await self.connect(proofKey: secret)
        guard let running = try? await self.version(of: client) else {
            return nil
        }

        if current, let apk = try Self.apk(environment: self.adb.environment), running != SHA256.hex(apk) {
            return nil
        }

        return client
    }

    /// Stops what runs, installs the tool's helper if needed and starts it with a new secret.
    private func startFresh() async throws -> AgentClient {
        guard let apk = try Self.apk(environment: self.adb.environment) else {
            throw Unavailable(description: """
                this hammer was built without the system helper. Set \(Self.apkEnvironmentKey) to its APK, \
                built with `./gradlew :hammer-system:assembleRelease` in android
                """)
        }

        try await self.stop()
        if try await self.isRunning() {
            throw Unavailable(description: Self.squatted)
        }

        try await self.install(apk)
        let secret = Self.newSecret()
        try await self.start(secret: secret)
        let client = try await self.connect(proofKey: Data(secret.utf8))
        do {
            _ = try await self.version(of: client)
        } catch is UnprovenServer {
            throw Unavailable(description: Self.squatted)
        }

        return client
    }

    private static let squatted = """
        another process listens on @\(socketName) and doesn't prove it is the system helper, so hammer won't \
        send it commands. Any app can take an abstract socket name; find it with \
        `adb shell cat /proc/net/unix`
        """

    /// Where the device keeps the secret of the running helper, readable only by adb's shell user.
    static let secretPath = "/data/local/tmp/hammer-system-secret"

    private static func newSecret() -> String {
        var generator = SystemRandomNumberGenerator()
        return (0..<32).map { _ in String(format: "%02x", UInt8.random(in: 0...255, using: &generator)) }
            .joined()
    }

    private func secret() async throws -> Data? {
        let command = "cat \(Self.secretPath) 2>/dev/null || true"
        let output = try await self.adb.run(["-s", self.serial, "shell", command])
        let secret = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return secret.isEmpty ? nil : Data(secret.utf8)
    }

    /// Whether the helper is listening on the device.
    func isRunning() async throws -> Bool {
        let listing = try await self.adb.run(["-s", self.serial, "shell", "cat /proc/net/unix"])
        return listing.split(separator: "\n").contains { $0.hasSuffix(" @\(Self.socketName)") }
    }

    /// Stops the helper if it runs, freeing UiAutomation for other tools. A helper that doesn't answer, or
    /// one this hammer can't verify, is stopped the hard way.
    func stop() async throws {
        guard try await self.isRunning() else {
            return
        }

        if let client = try await self.provenClient(current: false),
           (try? await client.run("stop", arguments: [:])) != nil,
           try await self.waitUntilStopped(within: Self.startTimeout)
        {
            return
        }

        try await self.adb.run(["-s", self.serial, "shell", "am", "force-stop", Self.packageName])
        _ = try await self.waitUntilStopped(within: .seconds(2))
    }

    private func waitUntilStopped(within timeout: Duration) async throws -> Bool {
        let deadline = ContinuousClock.now + timeout
        while try await self.isRunning() {
            guard ContinuousClock.now < deadline else {
                return false
            }

            try await Task.sleep(for: .milliseconds(100))
        }

        return true
    }

    /// Stops and removes the helper from the device.
    func uninstall() async throws {
        try await self.stop()
        if try await self.installedPath() != nil {
            try await self.adb.run(["-s", self.serial, "uninstall", Self.packageName])
        }
    }

    /// The helper's state on the device, for `hammer system status`.
    func status() async throws -> JSONValue {
        let running = try await self.isRunning()
        let installed = try await self.installedPath() != nil
        var status: [String: JSONValue] = ["installed": .bool(installed), "running": .bool(running)]
        if let apk = try? Self.apk(environment: self.adb.environment) {
            status["embedded"] = .string(SHA256.hex(apk))
        }
        if running, let client = try await self.provenClient(current: false),
           let version = try? await self.version(of: client)
        {
            status["version"] = .string(version)
        }

        return .object(status)
    }

    private func connect(proofKey: Data) async throws -> AgentClient {
        let socket = "localabstract:\(Self.socketName)"
        let list = try await self.adb.run(["-s", self.serial, "forward", "--list"])
        if let port = AndroidDevice.forwardedPort(in: list, serial: self.serial, socket: socket) {
            return AgentClient(port: port, token: nil, proofKey: proofKey)
        }

        let output = try await self.adb.run(["-s", self.serial, "forward", "tcp:0", socket])
        guard let port = UInt16(output.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw Unavailable(description: "adb forward printed \"\(output)\" instead of a port")
        }

        return AgentClient(port: port, token: nil, proofKey: proofKey)
    }

    private func version(of client: AgentClient) async throws -> String? {
        let output = try await client.run("version", arguments: [:])
        let fields = try JSONDecoder().decode([String: JSONValue].self, from: output)
        guard case .string(let version)? = fields["version"] else {
            return nil
        }

        return version
    }

    private func installedPath() async throws -> String? {
        let prefix = "package:"
        let command = "pm path \(Self.packageName) || true"
        let output = try await self.adb.run(["-s", self.serial, "shell", command])
        return output.split(separator: "\n").first { $0.hasPrefix(prefix) }
            .map { String($0.dropFirst(prefix.count)) }
    }

    /// Installs the APK unless the device has it. A helper signed with another key is removed first, since
    /// Android won't update an app with a different signature.
    private func install(_ apk: Data) async throws {
        if let path = try await self.installedPath() {
            let digest = try await self.adb.run(["-s", self.serial, "shell", "sha256sum '\(path)' || true"])
            if digest.hasPrefix(SHA256.hex(apk)) {
                return
            }

            try await self.adb.run(["-s", self.serial, "uninstall", Self.packageName])
        }

        let file = FileManager.default.temporaryDirectory
            .appending(path: "hammer-system-\(UUID().uuidString).apk")
        try apk.write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        do {
            try await self.adb.run(["-s", self.serial, "install", "-r", "-t", file.path],
                                   timeout: .seconds(120))
        } catch let error as ClientError {
            throw Unavailable(
                description: "the device refused to install the system helper: \(error.description)")
        }
    }

    /// Starts the helper with the secret and waits for its socket. `am instrument -w` hosts the helper's
    /// UiAutomation connection, so it runs detached on the device rather than waiting in adb. It exits with
    /// the helper, so a helper that can't start, such as when another tool holds UiAutomation, fails the
    /// start at once. A start that times out is killed, so it can't take UiAutomation later.
    private func start(secret: String) async throws {
        // The secret goes to a file only adb's shell user can read, for later hammer processes. The device's
        // time comes next, so only this start's logcat lines explain a failure
        let command = "umask 077; printf %s \(secret) > \(Self.secretPath); date '+%m-%d %H:%M:%S.000'; "
            + "setsid nohup am instrument -w -e \(Self.secretArgument) \(secret) \(self.instrumentation) "
            + ">/dev/null 2>&1 </dev/null & echo pid:$!"
        let output = try await self.adb.run(["-s", self.serial, "shell", command])
        guard let (time, pid) = Self.startOutput(output) else {
            throw Unavailable(description: "Starting the system helper printed \"\(output)\"")
        }

        let check = "grep ' @\(Self.socketName)$' /proc/net/unix; kill -0 \(pid) 2>/dev/null || echo exited"
        let deadline = ContinuousClock.now + self.startWait
        repeat {
            let output = try await self.adb.run(["-s", self.serial, "shell", check])
            let lines = output.split(separator: "\n")
            if lines.contains(where: { $0.hasSuffix(" @\(Self.socketName)") }) {
                return
            }

            if lines.contains("exited") {
                throw Unavailable(description: try await self.startFailure(since: time))
            }

            try await Task.sleep(for: .milliseconds(100))
        } while ContinuousClock.now < deadline

        let kill = "kill \(pid); am force-stop \(Self.packageName)"
        try? await self.adb.run(["-s", self.serial, "shell", kill])
        throw Unavailable(description: try await self.startFailure(since: time))
    }

}

/// Starting the helper: what a start printed, why it failed, and how this host's starts take turns and
/// remember the last failure.
extension AndroidSystemHelper {
    /// How long a failed start keeps later commands from trying again.
    static let failureMemory: TimeInterval = 30

    private var hostFileStem: String {
        let serial = self.serial.map { $0.isLetter || $0.isNumber ? $0 : "_" }
        return self.stateDirectory.appending(path: "hammer-system-\(String(serial))").path
    }

    private func recentFailure() -> Unavailable? {
        let path = self.hostFileStem + ".failed"
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              let modified = attributes[.modificationDate] as? Date,
              Date().timeIntervalSince(modified) < Self.failureMemory,
              let reason = try? String(contentsOfFile: path, encoding: .utf8)
        else {
            return nil
        }

        return Unavailable(description: """
            \(reason) (from a start \(Int(Date().timeIntervalSince(modified))) seconds ago; run \
            `hammer system start --android` to try again now)
            """)
    }

    private func remember(_ failure: Unavailable) {
        try? Data(failure.description.utf8).write(to: URL(filePath: self.hostFileStem + ".failed"))
    }

    private func forgetFailure() {
        try? FileManager.default.removeItem(atPath: self.hostFileStem + ".failed")
    }

    /// Runs the body holding a lock for the device on this host, so two hammer processes don't install or
    /// start the helper at once, where one's install would stop the helper the other is starting.
    private func withStartLock<T>(_ body: () async throws -> T) async throws -> T {
        let descriptor = open(self.hostFileStem + ".lock", O_CREAT | O_RDWR, 0o600)
        guard descriptor >= 0 else {
            return try await body()
        }

        defer {
            flock(descriptor, LOCK_UN)
            close(descriptor)
        }
        // flock blocks, so it waits off the cooperative thread pool
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.global().async {
                flock(descriptor, LOCK_EX)
                continuation.resume()
            }
        }
        return try await body()
    }

    /// The `am instrument -e` argument with the start's secret. Mirrors `SystemServer.SECRET_ARGUMENT`.
    static let secretArgument = "secret"

    /// The device time and the process id the start command printed, ignoring other lines, such as a shell's
    /// linker warnings.
    static func startOutput(_ output: String) -> (time: String, pid: Int)? {
        let lines = output.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        let time = lines.first { $0.wholeMatch(of: #/\d\d-\d\d \d\d:\d\d:\d\d\.000/#) != nil }
        let pid = lines.compactMap { $0.hasPrefix("pid:") ? Int($0.dropFirst(4)) : nil }.last
        guard let time, let pid else {
            return nil
        }

        return (time, pid)
    }

    /// Why the helper didn't start, from the line it wrote to logcat after `time`.
    private func startFailure(since time: String) async throws -> String {
        let filter = "HammerSystem:E"
        let log = try? await self.adb.run(["-s", self.serial, "logcat", "-d", "-T", time, "-s", filter])
        let reason = log?.split(separator: "\n").last { $0.contains(" E HammerSystem: ") }
            .map { String($0.split(separator: " E HammerSystem: ", maxSplits: 1).last ?? "") }
        let seconds = self.startWait.components.seconds
        return reason ?? "the system helper didn't start within \(seconds) seconds"
    }
}
