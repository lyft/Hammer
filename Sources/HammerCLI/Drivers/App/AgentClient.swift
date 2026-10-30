import Foundation
import HammerAgentCore

/// Talks to the agent running in the app.
struct AgentClient: Driver {
    let port: UInt16
    let token: String?

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

    /// The commands the app runs, or the builtin ones with a note explaining why.
    func catalog() async -> DriverCatalog {
        do {
            return DriverCatalog(commands: try await self.commands(), note: nil)
        } catch {
            let reason = (error as? ClientError)?.description ?? String(describing: error)
            return DriverCatalog(commands: BuiltinCommands.all, note: """
                \(reason), so these are only the builtin commands. Commands the app adds appear once it runs.
                """)
        }
    }

    /// The commands the app runs, or the builtin ones when it is not running, to describe them anyway.
    ///
    /// - throws: An error if the app is running but its commands could not be read.
    func callableCommands() async throws -> [CommandDescriptor] {
        do {
            return try await self.commands()
        } catch ClientError.unreachable {
            return BuiltinCommands.all
        }
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
        if let token = self.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error as URLError {
            throw ClientError(error, port: self.port, timeout: request.timeoutInterval)
        }

        guard let status = (response as? HTTPURLResponse)?.statusCode, status != 200 else {
            return data
        }

        let body = (try? JSONDecoder().decode(AgentErrorBody.self, from: data))
            ?? AgentErrorBody(error: "The agent responded with status \(status)")
        throw ClientError.failed(body, isInvalidCall: status == 400 || status == 404)
    }
}

enum ClientError: Error, CustomStringConvertible {
    case unreachable(port: UInt16)
    case disconnected
    case timedOut(TimeInterval)
    /// The app rejected or failed the command, or the call itself was invalid.
    case failed(AgentErrorBody, isInvalidCall: Bool = false)

    init(_ error: URLError, port: UInt16, timeout: TimeInterval) {
        switch error.code {
        case .cannotConnectToHost, .cannotFindHost:
            self = .unreachable(port: port)
        case .networkConnectionLost:
            self = .disconnected
        case .timedOut:
            self = .timedOut(timeout)
        default:
            self = .failed(AgentErrorBody(error: error.localizedDescription))
        }
    }

    var description: String {
        switch self {
        case .unreachable(let port):
            return "No Hammer agent is listening on 127.0.0.1:\(port)"
        case .disconnected:
            return "The app closed the connection before responding, it may have crashed or been stopped"
        case .timedOut(let timeout):
            return "The app did not respond within \(Int(timeout)) seconds, its main thread may be blocked"
        case .failed(let body, _):
            return body.error
        }
    }

    var hint: String? {
        switch self {
        case .unreachable:
            return """
                Launch the app with `HammerAgent().start()` running in it, and pass --port or set \
                \(AgentEndpoint.portEnvironmentKey) if it uses another port than \(AgentEndpoint.defaultPort)
                """
        case .disconnected:
            return """
                The command may have run before the app stopped. Check the app is still running, relaunch it \
                if needed, and call describe to see its state before running the command again
                """
        case .timedOut:
            return """
                The command may still run or have run. Take a screenshot to see the app's state before \
                running it again, or pass a shorter timeout to waits
                """
        case .failed(let body, _):
            return body.hint
        }
    }

    var code: AgentErrorCode {
        switch self {
        case .unreachable:
            return .unreachable
        case .disconnected:
            return .disconnected
        case .timedOut:
            return .timedOut
        case .failed(let body, let isInvalidCall):
            return body.code ?? (isInvalidCall ? .invalidArguments : .failed)
        }
    }

    /// The error as the CLI and MCP server report it.
    var body: AgentErrorBody {
        return AgentErrorBody(error: self.description, code: self.code, hint: self.hint)
    }
}

extension AgentErrorBody {
    /// The body as one line of JSON, which is how the CLI and MCP server report every error.
    var jsonLine: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = (try? encoder.encode(self)) ?? Data()
        return String(bytes: data, encoding: .utf8) ?? self.error
    }
}
