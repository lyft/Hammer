import Foundation
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

    /// Set to `0` to run the whole screen through uiautomator without the helper.
    static let enabledEnvironmentKey = "HAMMER_SYSTEM_HELPER"

    /// How long a start waits for the helper's socket.
    static let startTimeout: Duration = .seconds(10)

    let adb: Adb
    let serial: String

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

    /// A client for the running helper, starting it first, and installing or replacing it when the device's
    /// differs from the tool's.
    ///
    /// - throws: `Unavailable` when the helper can't run, such as when the tool was built without it, the
    ///           device refuses the install, or another tool holds UiAutomation.
    func client() async throws -> AgentClient {
        let apk = try Self.apk(environment: self.adb.environment)
        // Asking a running helper for its version first saves the socket listing on every command
        let client = try await self.connect()
        if let running = try? await self.version(of: client) {
            guard let apk, running != SHA256.hex(apk) else {
                return client
            }

            try await self.stop()
        }

        guard let apk else {
            throw Unavailable(description: """
                this hammer was built without the system helper. Set \(Self.apkEnvironmentKey) to its APK, \
                built with `./gradlew :hammer-system:assembleRelease` in android
                """)
        }

        try await self.install(apk)
        try await self.start()
        return try await self.connect()
    }

    /// Whether the helper is listening on the device.
    func isRunning() async throws -> Bool {
        let listing = try await self.adb.run(["-s", self.serial, "shell", "cat /proc/net/unix"])
        return listing.split(separator: "\n").contains { $0.hasSuffix(" @\(Self.socketName)") }
    }

    /// Stops the helper if it runs, freeing UiAutomation for other tools.
    func stop() async throws {
        guard try await self.isRunning() else {
            return
        }

        _ = try? await self.connect().run("stop", arguments: [:])
        let deadline = ContinuousClock.now + Self.startTimeout
        while try await self.isRunning() {
            guard ContinuousClock.now < deadline else {
                // A helper that doesn't answer is stopped the hard way
                try await self.adb.run(["-s", self.serial, "shell", "am", "force-stop", Self.packageName])
                return
            }

            try await Task.sleep(for: .milliseconds(100))
        }
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
        if running, let version = try? await self.version(of: try await self.connect()) {
            status["version"] = .string(version)
        }

        return .object(status)
    }

    private func connect() async throws -> AgentClient {
        let socket = "localabstract:\(Self.socketName)"
        let list = try await self.adb.run(["-s", self.serial, "forward", "--list"])
        if let port = AndroidDevice.forwardedPort(in: list, serial: self.serial, socket: socket) {
            return AgentClient(port: port, token: nil)
        }

        let output = try await self.adb.run(["-s", self.serial, "forward", "tcp:0", socket])
        guard let port = UInt16(output.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw Unavailable(description: "adb forward printed \"\(output)\" instead of a port")
        }

        return AgentClient(port: port, token: nil)
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

    /// Starts the helper and waits for its socket. `am instrument -w` hosts the helper's UiAutomation
    /// connection, so it runs detached on the device rather than waiting in adb. It exits with the helper, so
    /// a helper that can't start, such as when another tool holds UiAutomation, fails the start at once.
    private func start() async throws {
        // The device's time first, so only this start's logcat lines explain a failure
        let command = "date '+%m-%d %H:%M:%S.000'; "
            + "setsid nohup am instrument -w \(self.instrumentation) >/dev/null 2>&1 </dev/null & echo $!"
        let output = try await self.adb.run(["-s", self.serial, "shell", command])
        let lines = output.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        guard lines.count == 2, let pid = Int(lines[1]) else {
            throw Unavailable(description: "Starting the system helper printed \"\(output)\"")
        }

        let check = "grep ' @\(Self.socketName)$' /proc/net/unix; kill -0 \(pid) 2>/dev/null || echo exited"
        let deadline = ContinuousClock.now + Self.startTimeout
        repeat {
            let output = try await self.adb.run(["-s", self.serial, "shell", check])
            let lines = output.split(separator: "\n")
            if lines.contains(where: { $0.hasSuffix(" @\(Self.socketName)") }) {
                return
            }

            if lines.contains("exited") {
                break
            }

            try await Task.sleep(for: .milliseconds(100))
        } while ContinuousClock.now < deadline

        throw Unavailable(description: try await self.startFailure(since: lines[0]))
    }

    /// Why the helper didn't start, from the line it wrote to logcat after `time`.
    private func startFailure(since time: String) async throws -> String {
        let filter = "HammerSystem:E"
        let log = try? await self.adb.run(["-s", self.serial, "logcat", "-d", "-T", time, "-s", filter])
        let reason = log?.split(separator: "\n").last { $0.contains(" E HammerSystem: ") }
            .map { String($0.split(separator: " E HammerSystem: ", maxSplits: 1).last ?? "") }
        let seconds = Self.startTimeout.components.seconds
        return reason ?? "the system helper didn't start within \(seconds) seconds"
    }
}
