import Foundation
import HammerAgentCore

/// An app on an Android device whose agent listens on the abstract socket `hammer_<applicationId>`.
struct AndroidDevice: Sendable {
    static let socketPrefix = "hammer_"

    let adb: Adb
    let serial: String
    let appID: String

    private var socket: String {
        return "localabstract:\(Self.socketPrefix)\(self.appID)"
    }

    /// Finds the device and the app to drive.
    ///
    /// - parameter adb:    The adb to run.
    /// - parameter serial: The device, or nil for `ANDROID_SERIAL` or the only attached one.
    /// - parameter appID:  The app's application id, or nil for the only app running an agent, or the
    ///                     focused one when several are.
    ///
    /// - throws: A `no_device` error if the device is ambiguous, missing or not ready, or `unreachable` if
    ///           no app runs an agent.
    static func resolve(adb: Adb, serial: String?, appID: String?) async throws -> AndroidDevice {
        let serial = try await self.resolveSerial(adb: adb, serial: serial)
        if let appID {
            return AndroidDevice(adb: adb, serial: serial, appID: appID)
        }

        let appID = try await self.resolveAppID(adb: adb, serial: serial)
        return AndroidDevice(adb: adb, serial: serial, appID: appID)
    }

    /// The device to drive: the serial passed, or `ANDROID_SERIAL`, or the only device that is ready.
    ///
    /// - throws: A `no_device` error naming the devices and their states when none fits.
    static func resolveSerial(adb: Adb, serial: String?) async throws -> String {
        let output: String
        do {
            output = try await adb.run(["devices"])
        } catch let error as ClientError where error.code != .noDevice {
            throw ClientError.noDevice("adb can't list the devices: \(error.description)",
                                       hint: "Run `adb kill-server` and try again")
        }

        let attached = self.attachedDevices(in: output)
        let requested = serial ?? adb.environment[Adb.serialEnvironmentKey].flatMap { $0.isEmpty ? nil : $0 }
        if let requested {
            guard let state = attached.first(where: { $0.serial == requested })?.state else {
                throw ClientError.noDevice("No attached device has the serial \(requested)",
                                           hint: self.attachedHint(attached))
            }

            guard state == "device" else {
                throw ClientError.noDevice("\(requested) is \(state)", hint: self.stateHint(state))
            }

            return requested
        }

        let ready = attached.filter { $0.state == "device" }
        if ready.count == 1, let only = ready.first {
            return only.serial
        }

        if ready.isEmpty, let waiting = attached.first {
            throw ClientError.noDevice("No Android device is ready: \(waiting.serial) is \(waiting.state)",
                                       hint: self.stateHint(waiting.state))
        }

        let description = ready.isEmpty
            ? "No Android device or emulator is attached" : "\(ready.count) Android devices are attached"
        throw ClientError.noDevice(description, hint: self.attachedHint(attached))
    }

    /// A local port forwarded to the app's agent, reusing the forward an earlier call opened.
    ///
    /// Forwards stay open so the next call skips opening one, and so a stopped call leaves nothing behind
    /// but a forward the next one reuses. `adb forward --remove-all` removes them.
    ///
    /// - returns: The local port.
    func forward() async throws -> UInt16 {
        let list = try await self.adb.run(["-s", self.serial, "forward", "--list"])
        if let port = Self.forwardedPort(in: list, serial: self.serial, socket: self.socket) {
            return port
        }

        let output = try await self.adb.run(["-s", self.serial, "forward", "tcp:0", self.socket])
        guard let port = UInt16(output.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw ClientError.failed(AgentErrorBody(
                error: "adb forward printed \"\(output)\" instead of a port", code: .failed,
                hint: "Run `adb -s \(self.serial) forward --remove-all` and try again"))
        }

        return port
    }

    /// The error for a forward that refused the connection, such as after the adb server restarted.
    var refusedError: ClientError {
        return Self.unreachable("""
            The Hammer agent of \(self.appID) on \(self.serial) didn't accept the connection through adb
            """, hint: "Try again, which opens a new forward, or relaunch the app")
    }

    /// The error for an app whose agent isn't listening.
    ///
    /// - returns: An `unreachable` error naming the apps that do run an agent, or nil if this one is
    ///            listening or the sockets can't be read, so the original error stands.
    func notListeningError() async -> ClientError? {
        guard let listening = await Self.listeningAppIDs(adb: self.adb, serial: self.serial),
              !listening.contains(self.appID)
        else {
            return nil
        }

        let running = listening.isEmpty
            ? "No app runs one" : "Apps that do: \(listening.joined(separator: ", "))"
        return Self.unreachable("\(self.appID) runs no Hammer agent on \(self.serial). \(running)", hint: """
            Launch a debug build of \(self.appID) with the Hammer agent, or pass another --app-id
            """)
    }

    /// Whether Android froze the app's process, as it does to cached apps soon after they leave the screen,
    /// so its agent can't respond. False when it can't be read.
    func isFrozen() async -> Bool {
        let command = ["-s", self.serial, "shell", "dumpsys", "activity", "processes", self.appID]
        let processes = try? await self.adb.run(command)
        return processes.map { Self.isFrozen(in: $0, appID: self.appID) } ?? false
    }

    /// The error for an app Android froze in the background.
    var frozenError: ClientError {
        return .failed(AgentErrorBody(error: """
            Android froze \(self.appID) on \(self.serial) in the background, so its Hammer agent can't respond
            """, code: .appFrozen,
            hint: "Bring the app to the front and try again. The agent drops the command hammer gave up on"))
    }

    // MARK: - Resolving

    private static func resolveAppID(adb: Adb, serial: String) async throws -> String {
        let listing = try await adb.run(["-s", serial, "shell", "cat", "/proc/net/unix"])
        let listening = self.listeningAppIDs(in: listing)
        if listening.count == 1, let only = listening.first {
            return only
        }

        guard !listening.isEmpty else {
            throw self.unreachable("No app on \(serial) runs a Hammer agent", hint: """
                Launch a debug build of the app with the Hammer agent, or pass --app-id
                """)
        }

        let windows = try await adb.run(["-s", serial, "shell", self.focusCommand])
        if let focused = self.focusedAppIDs(in: windows).first(where: listening.contains) {
            return focused
        }

        throw ClientError.noDevice("""
            \(listening.count) apps on \(serial) run a Hammer agent and none has focus: \
            \(listening.joined(separator: ", "))
            """, hint: "Pass --app-id with one of them")
    }

    private static func attachedHint(_ attached: [(serial: String, state: String)]) -> String {
        let pick = "Pass --serial or set \(Adb.serialEnvironmentKey) to the device to drive"
        let list = attached.map { "\($0.serial) (\($0.state))" }.joined(separator: ", ")
        return attached.isEmpty
            ? "Boot an emulator or connect a device, and check `adb devices` lists it as `device`"
            : "\(pick). Attached: \(list)"
    }

    private static func stateHint(_ state: String) -> String {
        switch state {
        case "unauthorized":
            return "Accept the USB debugging prompt on the device, then try again"
        case "offline":
            return "Reconnect the device or restart the emulator, or run `adb kill-server`"
        default:
            return "Wait for the device to finish starting, and check `adb devices` lists it as `device`"
        }
    }

    private static func unreachable(_ description: String, hint: String) -> ClientError {
        return .failed(AgentErrorBody(error: description, code: .unreachable, hint: hint))
    }

    /// The listening apps, or nil if they can't be read, so a check never hides the original error.
    private static func listeningAppIDs(adb: Adb, serial: String) async -> [String]? {
        let listing = try? await adb.run(["-s", serial, "shell", "cat", "/proc/net/unix"])
        return listing.map(self.listeningAppIDs(in:))
    }

    // MARK: - Parsing

    /// Whether `dumpsys activity processes` shows the app's main process as frozen. Other processes of the
    /// app, such as `:remote` or a WebView sandbox, are listed apart and don't run the agent.
    static func isFrozen(in processes: String, appID: String) -> Bool {
        return processes.components(separatedBy: "*APP*").dropFirst().contains { block in
            // The header names the process, such as ProcessRecord{9029806 6392:com.example/u0a268}
            let header = block.prefix { $0 != "\n" }
            return header.contains(":\(appID)/") && block.contains("isFrozen=true")
        }
    }

    /// The devices `adb devices` lists, with their state, such as `device`, `unauthorized` or `offline`.
    static func attachedDevices(in output: String) -> [(serial: String, state: String)] {
        return output.split(separator: "\n").dropFirst().compactMap { line in
            let parts = line.split(separator: "\t", maxSplits: 1).map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            guard parts.count == 2, !parts[0].isEmpty, !parts[0].hasPrefix("*") else {
                return nil
            }

            return (parts[0], parts[1])
        }
    }

    /// The port of an existing forward to the socket in `adb forward --list`, whose lines are
    /// `<serial> tcp:<port> <socket>`.
    static func forwardedPort(in list: String, serial: String, socket: String) -> UInt16? {
        return list.split(separator: "\n").lazy.compactMap { line -> UInt16? in
            let columns = line.split(whereSeparator: \.isWhitespace)
            guard columns.count == 3, columns[0] == serial, columns[2] == socket, columns[1].hasPrefix("tcp:")
            else {
                return nil
            }

            return UInt16(columns[1].dropFirst(4))
        }.first
    }

    /// The `__SO_ACCEPTCON` bit of `/proc/net/unix`'s Flags column, set on listening sockets.
    private static let listeningFlag = 0x10000

    /// The application ids of listening `@hammer_<applicationId>` sockets in `/proc/net/unix`, whose columns
    /// are `Num RefCount Protocol Flags Type St Inode Path`.
    static func listeningAppIDs(in listing: String) -> [String] {
        let prefix = "@\(self.socketPrefix)"
        let ids = listing.split(separator: "\n").dropFirst().compactMap { line -> String? in
            let columns = line.split(whereSeparator: \.isWhitespace)
            guard columns.count >= 8, columns[7].hasPrefix(prefix),
                  let flags = Int(columns[3], radix: 16), flags & self.listeningFlag != 0
            else {
                return nil
            }

            return String(columns[7].dropFirst(prefix.count))
        }

        return Array(Set(ids)).sorted()
    }

    /// Prints the window manager's focus, which every version since Android 9 lists.
    static let focusCommand = "dumpsys window | grep -E 'mCurrentFocus|mFocusedApp'; "
        + "dumpsys activity activities | grep -E 'Task(Record)?\\{' || true"

    /// The application ids in `focusCommand`'s output: the focused window's, the focused activity's, then the
    /// affinity of the focused activity's task, so a caller can pick the first that runs an agent. A
    /// permission dialog is another app's activity, but it runs in the task of the app that asked.
    static func focusedAppIDs(in output: String) -> [String] {
        var ids = [String]()
        for key in ["mCurrentFocus", "mFocusedApp"] {
            // Android 9 nests the record, as in mFocusedApp=AppWindowToken{… ActivityRecord{… u0 app/.Main}}
            let pattern = try? Regex(#"\#(key)=[^\n]*? u\d+ ([^\s/}]+)/"#)
            if let pattern, let match = output.firstMatch(of: pattern), let id = match.output[1].substring,
               !ids.contains(String(id))
            {
                ids.append(String(id))
            }
        }

        // The task line, such as Task{c26d958 #142 type=standard A=10268:com.example …}, or on Android 9
        // TaskRecord{… #17 A=com.example …}
        if let task = output.firstMatch(of: #/mFocusedApp=[^\n]* t(\d+)\}/#)?.output.1,
           let pattern = try? Regex(#"Task(?:Record)?\{\S+ #\#(task) [^\n]*?A=(?:\d+:)?([^\s}]+)"#),
           let affinity = output.firstMatch(of: pattern)?.output[1].substring, !ids.contains(String(affinity))
        {
            ids.append(String(affinity))
        }

        return ids
    }
}
