import Foundation
import HammerAgentCore

/// An app on an Android device whose agent listens on the abstract socket `hammer_<applicationId>`.
struct AndroidDevice: Sendable {
    static let socketPrefix = "hammer_"

    let adb: Adb
    let serial: String
    let appID: String

    /// Finds the device and the app to drive.
    ///
    /// - parameter adb:    The adb to run.
    /// - parameter serial: The device, or nil for `ANDROID_SERIAL` or the only attached one.
    /// - parameter appID:  The app's application id, or nil for the only app running an agent, or the
    ///                     foreground one when several are.
    ///
    /// - throws: A `no_device` error if the device is ambiguous or missing, or `unreachable` if no app runs
    ///           an agent.
    static func resolve(adb: Adb, serial: String?, appID: String?) throws -> AndroidDevice {
        let serial = try self.resolveSerial(adb: adb, serial: serial)
        guard let appID else {
            let appID = try self.resolveAppID(adb: adb, serial: serial)
            return AndroidDevice(adb: adb, serial: serial, appID: appID)
        }

        return AndroidDevice(adb: adb, serial: serial, appID: appID)
    }

    /// Forwards a free local port to the app's agent.
    ///
    /// - returns: The local port.
    func forward() throws -> UInt16 {
        let socket = "localabstract:\(Self.socketPrefix)\(self.appID)"
        let output = try self.adb.run(["-s", self.serial, "forward", "tcp:0", socket])
        guard let port = UInt16(output.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw ClientError.noDevice("adb forward printed \"\(output)\" instead of a port",
                                       hint: "Run `adb -s \(self.serial) forward --remove-all` and try again")
        }

        return port
    }

    /// Removes a forward from `forward()`. Failures are ignored, since the call already finished.
    func removeForward(_ port: UInt16) {
        _ = try? self.adb.run(["-s", self.serial, "forward", "--remove", "tcp:\(port)"])
    }

    /// Checks the app's agent is listening.
    ///
    /// - throws: An `unreachable` error naming the apps that do run an agent, if it is not.
    func checkListening() throws {
        let listening = Self.listeningAppIDs(adb: self.adb, serial: self.serial)
        guard let listening, !listening.contains(self.appID) else {
            return
        }

        let running = listening.isEmpty
            ? "No app runs one" : "Apps that do: \(listening.joined(separator: ", "))"
        let hint = "Launch a debug build of \(self.appID) with the Hammer agent, or pass another --app-id"
        throw Self.notRunning("\(self.appID) runs no Hammer agent on \(self.serial). \(running)", hint: hint)
    }

    // MARK: - Resolving

    /// The device to drive: the serial passed, or `ANDROID_SERIAL`, or the only attached device.
    static func resolveSerial(adb: Adb, serial: String?) throws -> String {
        let attached = try self.attachedSerials(adb: adb)
        let requested = serial ?? ProcessInfo.processInfo.environment[Adb.serialEnvironmentKey].flatMap {
            $0.isEmpty ? nil : $0
        }
        if let requested {
            guard attached.contains(requested) else {
                throw ClientError.noDevice("No attached device has the serial \(requested)",
                                           hint: self.attachedHint(attached))
            }

            return requested
        }

        guard attached.count == 1, let only = attached.first else {
            let description = attached.isEmpty
                ? "No Android device or emulator is attached"
                : "\(attached.count) Android devices are attached"
            throw ClientError.noDevice(description, hint: self.attachedHint(attached))
        }

        return only
    }

    private static func resolveAppID(adb: Adb, serial: String) throws -> String {
        let listing = try adb.run(["-s", serial, "shell", "cat", "/proc/net/unix"])
        let listening = self.listeningAppIDs(in: listing)
        if listening.count == 1, let only = listening.first {
            return only
        }

        guard !listening.isEmpty else {
            throw self.notRunning("No app on \(serial) runs a Hammer agent",
                                  hint: """
                                    Launch a debug build of the app with the Hammer agent, or pass --app-id
                                    """)
        }

        let activities = try adb.run(["-s", serial, "shell", "dumpsys", "activity", "activities"])
        if let foreground = self.resumedAppID(in: activities), listening.contains(foreground) {
            return foreground
        }

        throw ClientError.noDevice("""
            \(listening.count) apps on \(serial) run a Hammer agent and none is in the foreground: \
            \(listening.joined(separator: ", "))
            """, hint: "Pass --app-id with one of them")
    }

    private static func attachedSerials(adb: Adb) throws -> [String] {
        return try adb.run(["devices"]).split(separator: "\n").dropFirst().compactMap { line in
            let parts = line.split(whereSeparator: \.isWhitespace)
            return parts.count == 2 && parts[1] == "device" ? String(parts[0]) : nil
        }
    }

    private static func attachedHint(_ attached: [String]) -> String {
        let pick = "Pass --serial or set \(Adb.serialEnvironmentKey) to the device to drive"
        return attached.isEmpty
            ? "Boot an emulator or connect a device, and check `adb devices` lists it as `device`"
            : "\(pick). Attached: \(attached.joined(separator: ", "))"
    }

    private static func notRunning(_ description: String, hint: String) -> ClientError {
        return .failed(AgentErrorBody(error: description, code: .unreachable, hint: hint))
    }

    /// The listening apps, or nil if they can't be read, so a check never hides the original error.
    private static func listeningAppIDs(adb: Adb, serial: String) -> [String]? {
        return (try? adb.run(["-s", serial, "shell", "cat", "/proc/net/unix"])).map(self.listeningAppIDs(in:))
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

    /// The application id of the resumed activity in `dumpsys activity activities`.
    static func resumedAppID(in activities: String) -> String? {
        let pattern = #/ResumedActivity[:=]\s*ActivityRecord\{\S+ u\d+ ([^/\s]+)//#
        return activities.firstMatch(of: pattern).map { String($0.1) }
    }
}
