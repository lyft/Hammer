import Foundation
import HammerAgentCore

/// Talks to the agent running in the app.
struct AgentClient: Sendable {
    let port: UInt16

    private var baseURL: URL {
        return URL(string: "http://127.0.0.1:\(self.port)")!
    }

    /// The commands the app runs.
    ///
    /// - throws: An error if the agent is not reachable.
    func commands() async throws -> [CommandDescriptor] {
        let url = self.baseURL.appending(path: AgentEndpoint.commandsPath)
        let data = try await self.send(URLRequest(url: url))
        return try JSONDecoder().decode([CommandDescriptor].self, from: data)
    }

    /// The commands the app runs, or the builtin ones when it is not reachable, to describe them anyway.
    func commandsOrBuiltins() async -> [CommandDescriptor] {
        return (try? await self.commands()) ?? BuiltinCommands.all
    }

    /// Runs a command.
    ///
    /// - parameter name:      The name of the command.
    /// - parameter arguments: The arguments object.
    ///
    /// - throws: An error if the agent is not reachable or the command failed.
    ///
    /// - returns: The command's JSON output.
    func run(_ name: String, arguments: [String: JSONValue]) async throws -> Data {
        var request = URLRequest(url: self.baseURL.appending(path: AgentEndpoint.commandPath(name)))
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(arguments)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await self.send(request)
    }

    private func send(_ request: URLRequest) async throws -> Data {
        var request = request
        // Commands such as waits and long presses take a while, and the app runs them one at a time
        request.timeoutInterval = 300

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error as URLError where error.code == .cannotConnectToHost {
            throw ClientError.unreachable(port: self.port)
        }

        guard let status = (response as? HTTPURLResponse)?.statusCode, status != 200 else {
            return data
        }

        let message = (try? JSONDecoder().decode(AgentErrorBody.self, from: data))?.error
        throw ClientError.failed(message ?? "The agent responded with status \(status)")
    }
}

enum ClientError: Error, CustomStringConvertible {
    case unreachable(port: UInt16)
    case failed(String)

    var description: String {
        switch self {
        case .unreachable(let port):
            return """
                No Hammer agent is listening on 127.0.0.1:\(port). Start it in the app with \
                `HammerAgent().start()`, or set \(AgentEndpoint.portEnvironmentKey) to the port it uses.
                """
        case .failed(let message):
            return message
        }
    }
}
