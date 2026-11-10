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
        return try await self.withAgent { try await $0.run(name, arguments: arguments) }
    }

    private func withAgent<T: Sendable>(_ body: (AgentClient) async throws -> T) async throws -> T {
        let (device, port) = try await self.connection.endpoint {
            let device = try await AndroidDevice.resolve(adb: self.adb, serial: self.serial,
                                                         appID: self.appID)
            return (device, try await device.forward())
        }

        do {
            return try await body(AgentClient(port: port, token: self.token))
        } catch let error as ClientError where [.unreachable, .disconnected].contains(error.code) {
            // adb forwards to sockets that don't exist, which only shows once the connection drops
            await self.connection.reset()
            if let notListening = await device.notListeningError() {
                throw notListening
            }

            throw error.code == .unreachable ? device.refusedError : error
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
