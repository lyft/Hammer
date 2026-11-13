#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Foundation
import HammerAgentCore

/// Talks to the agent in an Android app, through a port `adb forward` opens.
///
/// It finds the device, the app and the forward once and keeps them for its life, such as an MCP server's,
/// finding them again after a call can't reach the agent.
struct AndroidAgentClient: Driver {
    let adb: Adb
    let serial: String?
    let appID: String?
    let token: String?

    private let connection = AndroidConnection()

    init(adb: Adb, serial: String?, appID: String?, token: String?) {
        self.adb = adb
        self.serial = serial
        self.appID = appID
        self.token = token
    }

    func catalog() async -> DriverCatalog {
        do {
            return DriverCatalog(commands: try await self.withAgent { try await $0.commands() }, note: nil)
        } catch {
            let reason = (error as? ClientError)?.description ?? String(describing: error)
            return DriverCatalog(commands: BuiltinCommands.all(for: .android), note: """
                \(reason), so these are only the built-in commands of an Android agent. Commands the app \
                adds appear once it runs.
                """)
        }
    }

    /// The commands the app runs, or the built-in ones when no agent runs, so a call gets its usual error.
    func callableCommands() async throws -> [CommandDescriptor] {
        do {
            return try await self.withAgent { try await $0.commands() }
        } catch let error as ClientError where error.code == .unreachable {
            return BuiltinCommands.all(for: .android)
        }
    }

    func run(_ name: String, arguments: [String: JSONValue]) async throws -> Data {
        let arguments = try await self.resolvingSystemRefs(in: arguments, for: name)
        do {
            let output = try await self.withAgent { try await $0.run(name, arguments: arguments) }
            let isDescribe = name == BuiltinCommands.Android.describe.name
            return isDescribe ? await self.fillingSystemReads(output) : output
        } catch let error as ClientError where error.code == .notFound {
            guard let point = try await self.systemContentPoint(for: arguments, of: name) else {
                throw error
            }

            var arguments = arguments
            for key in ["identifier", "label", "value", "traits"] {
                arguments[key] = nil
            }
            arguments["x"] = .number(point.x)
            arguments["y"] = .number(point.y)
            return try await self.withAgent { [arguments] in try await $0.run(name, arguments: arguments) }
        }
    }

    private func withAgent<T: Sendable>(_ body: @escaping @Sendable (AgentClient) async throws -> T)
        async throws -> T
    {
        return try await self.call(body, mayRetry: true)
    }

    /// Calls the agent, retrying once when that can't run the command twice: after a refused connection,
    /// which sent nothing, or after the app hammer picked was frozen and another app is now in front, since
    /// an agent drops a request whose connection closed.
    private func call<T: Sendable>(_ body: @escaping @Sendable (AgentClient) async throws -> T,
                                   mayRetry: Bool) async throws -> T
    {
        let (device, port) = try await self.connection.endpoint(self.find)
        let client = AgentClient(port: port, token: self.token)
        do {
            return try await Self.failingWhenFrozen(isFrozen: { await device.isFrozen() },
                                                    call: { try await body(client) })
        } catch is AppFrozen {
            if mayRetry && self.appID == nil {
                await self.connection.reset()
                let (next, _) = try await self.connection.endpoint(self.find)
                if next.appID != device.appID {
                    return try await self.call(body, mayRetry: false)
                }
            }

            // The forward works, so the connection is kept for when the app is back
            throw device.frozenError
        } catch let error as ClientError where [.unreachable, .disconnected].contains(error.code) {
            // adb forwards to sockets that don't exist, which only shows once the connection drops
            await self.connection.reset()
            if let notListening = await device.notListeningError() {
                throw notListening
            }

            // A refused connection sent nothing, such as after the adb server restarted and lost the forward
            if error.code == .unreachable && mayRetry {
                return try await self.call(body, mayRetry: false)
            }

            throw error.code == .unreachable ? device.refusedError : error
        }
    }

    @Sendable
    private func find() async throws -> (AndroidDevice, UInt16) {
        let device = try await AndroidDevice.resolve(adb: self.adb, serial: self.serial, appID: self.appID)
        return (device, try await device.forward())
    }
}

extension AndroidAgentClient {
    /// How many times describe reads a web view whose content is empty, and how long it waits between.
    static let systemReadAttempts = 3
    static let systemReadRetryDelay: Duration = .milliseconds(300)

    /// Describe's output with the content of the views marked `needsSystemRead` read through the system
    /// helper, or the output as it is, with a note, when the helper can't read them.
    private func fillingSystemReads(_ output: Data) async -> Data {
        guard let nodes = try? JSONDecoder().decode([JSONValue].self, from: output) else {
            return output
        }

        let regions = SystemReads.regions(in: nodes)
        guard !regions.isEmpty else {
            return output
        }

        do {
            var contents: [[JSONValue]?] = []
            for attempt in 1...Self.systemReadAttempts {
                let windows = try await self.appWindows()
                contents = SystemReads.contents(of: regions, in: windows)
                // A web view builds its accessibility tree on the first read, so that one can come back
                // empty. Other views read the same every time, and a view the helper didn't find won't appear
                let isBuilding = zip(regions, contents).contains { $0.isWebView && $1?.isEmpty == true }
                guard attempt < Self.systemReadAttempts, isBuilding else {
                    break
                }

                try await Task.sleep(for: Self.systemReadRetryDelay)
            }

            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            return try encoder.encode(SystemReads.merge(nodes, contents: contents))
        } catch {
            Self.note("the content of the views marked needsSystemRead wasn't read: \(Self.reason(error))")
            return output
        }
    }

    /// The arguments with each ref from the system helper, such as `s1a2b3c4d`, replaced by the point of
    /// the element it names, after reading the screen again to check the element is still there.
    private func resolvingSystemRefs(in arguments: [String: JSONValue], for name: String) async throws
        -> [String: JSONValue]
    {
        var arguments = arguments
        for prefix in ["", "to_"] {
            guard case .string(let ref)? = arguments[prefix + "ref"], ref.hasPrefix(SystemReads.refPrefix),
                  Self.takesPoint(name, prefix: prefix)
            else {
                continue
            }

            let windows: [AndroidElement]
            do {
                windows = try await self.appWindows()
            } catch {
                throw ClientError.failed(.init(
                    error: "Ref \(ref) is from the system helper, which can't read the screen: "
                        + Self.reason(error),
                    code: .notReady, hint: "Pass the element's x and y from describe instead"))
            }

            guard let point = SystemReads.point(of: ref, in: windows) else {
                throw ClientError.failed(.init(
                    error: "Unknown ref \(ref)", code: .notFound,
                    hint: "Refs of web content change when it moves or changes, call describe for the "
                        + "current ones"))
            }

            arguments[prefix + "ref"] = nil
            arguments[prefix + "x"] = .number(point.x)
            arguments[prefix + "y"] = .number(point.y)
        }

        return arguments
    }

    /// The point of the one element a query the agent didn't find matches in the content it can't read,
    /// or nil when there is no such content or the query matches nothing in it.
    private func systemContentPoint(for arguments: [String: JSONValue], of name: String) async throws
        -> CGPoint?
    {
        guard Self.takesPoint(name, prefix: ""),
              let query = try? JSONDecoder().decode(ScreenTarget.self, from: JSONEncoder().encode(arguments))
                .query(traitNames: AndroidSystemCommands.traitNames)
        else {
            return nil
        }

        let output = try await self.withAgent { try await $0.run(BuiltinCommands.Android.describe.name,
                                                                arguments: [:]) }
        let regions = SystemReads.regions(in: try JSONDecoder().decode([JSONValue].self, from: output))
        guard !regions.isEmpty, let windows = try? await self.appWindows() else {
            return nil
        }

        let content = SystemReads.contents(of: regions, in: windows).compactMap { $0 }.flatMap { $0 }
        let matches = SystemReads.matches(query, in: content)
        guard matches.count < 2 else {
            throw ClientError.failed(.init(
                error: "Found \(matches.count) elements for \(query) in content the system helper read",
                code: .ambiguousTarget, hint: "Pass one's ref from describe"))
        }

        return matches.first.flatMap { SystemReads.frame(of: $0) }.map { CGPoint(x: $0.midX, y: $0.midY) }
    }

    /// The app's windows through the system helper, in dp. App commands use a helper that already runs, since
    /// starting one takes UiAutomation from UI tests and uiautomator, unless
    /// `HAMMER_SYSTEM_HELPER=auto` lets them start it.
    private func appWindows() async throws -> [AndroidElement] {
        let (device, _) = try await self.connection.endpoint(self.find)
        let environment = self.adb.environment
        guard AndroidSystemHelper.isEnabled(environment: environment) else {
            throw AndroidSystemHelper.Unavailable(
                description: "\(AndroidSystemHelper.enabledEnvironmentKey) is 0")
        }

        let helper = AndroidSystemHelper(adb: self.adb, serial: device.serial)
        let client: AgentClient
        if AndroidSystemHelper.startsForAppCommands(environment: environment) {
            client = try await helper.client()
        } else if let running = try await helper.runningClient() {
            client = running
        } else {
            throw AndroidSystemHelper.Unavailable(description: """
                the system helper isn't running. Start it with `hammer system start --android`, or set \
                \(AndroidSystemHelper.enabledEnvironmentKey)=auto to let app commands start it
                """)
        }

        let screen = HelperScreen(client: client, adb: self.adb, serial: device.serial)
        let metrics = try await screen.metrics()
        return try await screen.windows(of: device.appID, scale: metrics.scale)
    }

    /// Whether the command takes a point for the target with the prefix, so a ref can become one.
    private static func takesPoint(_ name: String, prefix: String) -> Bool {
        let descriptor = BuiltinCommands.Android.all.first { $0.name == name }
        return descriptor?.parameters.contains { $0.name == prefix + "x" } == true
    }

    private static func reason(_ error: Error) -> String {
        return (error as? ClientError)?.description ?? String(describing: error)
    }

    private static func note(_ text: String) {
        FileHandle.standardError.write(Data("note: \(text)\n".utf8))
    }

    /// How often a call checks whether Android froze the app while it waits for the agent.
    static let frozenCheckDelay: Duration = .seconds(5)

    /// Thrown when a call is slow because Android froze the app.
    struct AppFrozen: Error {}

    /// Runs the call, failing it with `AppFrozen` when Android froze the app in the background, where the
    /// call would otherwise wait for its whole timeout. The app is checked every `delay` while the call runs.
    static func failingWhenFrozen<T: Sendable>(delay: Duration = Self.frozenCheckDelay,
                                               isFrozen: @escaping @Sendable () async -> Bool,
                                               call: @escaping @Sendable () async throws -> T)
        async throws -> T
    {
        return try await withThrowingTaskGroup(of: T?.self) { group in
            group.addTask { try await call() }
            group.addTask {
                // Checked for as long as the call runs, since the app can freeze during a long wait_for
                repeat {
                    try await Task.sleep(for: delay)
                    if await isFrozen() {
                        throw AppFrozen()
                    }
                } while !Task.isCancelled
                return nil
            }

            while let result = try await group.next() {
                if let result {
                    group.cancelAll()
                    return result
                }
            }

            preconditionFailure("The call's task always returns or throws")
        }
    }
}

/// The device, app and port a client found, kept until a call can't reach the agent.
private actor AndroidConnection {
    private var endpoint: (device: AndroidDevice, port: UInt16)?

    func endpoint(_ find: @Sendable () async throws -> (AndroidDevice, UInt16)) async throws
        -> (AndroidDevice, UInt16)
    {
        if let endpoint = self.endpoint {
            return endpoint
        }

        let endpoint = try await find()
        self.endpoint = endpoint
        return endpoint
    }

    func reset() {
        self.endpoint = nil
    }
}
