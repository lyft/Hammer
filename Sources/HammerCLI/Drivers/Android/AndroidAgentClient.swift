import Foundation
import HammerAgentCore

/// Talks to the agent in an Android app, through a port `adb forward` opens for each call.
struct AndroidAgentClient: Driver {
    let adb: Adb
    let serial: String?
    let appID: String?
    let token: String?

    // The builtin commands describe the iOS agent, so the app's commands are only known once it runs
    func catalog() async -> DriverCatalog {
        do {
            return DriverCatalog(commands: try await self.callableCommands(), note: nil)
        } catch {
            let reason = (error as? ClientError)?.description ?? String(describing: error)
            return DriverCatalog(commands: [], note: "\(reason), so its commands are unknown until it runs")
        }
    }

    func callableCommands() async throws -> [CommandDescriptor] {
        return try await self.withAgent { try await $0.commands() }
    }

    func run(_ name: String, arguments: [String: JSONValue]) async throws -> Data {
        return try await self.withAgent { try await $0.run(name, arguments: arguments) }
    }

    private func withAgent<T: Sendable>(_ body: (AgentClient) async throws -> T) async throws -> T {
        let device = try AndroidDevice.resolve(adb: self.adb, serial: self.serial, appID: self.appID)
        let port = try device.forward()
        defer { device.removeForward(port) }
        do {
            return try await body(AgentClient(port: port, token: self.token))
        } catch let error as ClientError where [.unreachable, .disconnected].contains(error.code) {
            // adb forwards to sockets that don't exist, which only shows once the connection drops
            try device.checkListening()
            throw error
        }
    }
}

/// Stands in for the system driver on Android, which Hammer doesn't have yet.
struct UnavailableDriver: Driver {
    let reason: String

    func catalog() async -> DriverCatalog {
        return DriverCatalog(commands: [], note: self.reason)
    }

    func callableCommands() async throws -> [CommandDescriptor] {
        return []
    }

    func run(_ name: String, arguments: [String: JSONValue]) async throws -> Data {
        let body = AgentErrorBody(error: self.reason, code: .invalidArguments)
        throw ClientError.failed(body, isInvalidCall: true)
    }
}
