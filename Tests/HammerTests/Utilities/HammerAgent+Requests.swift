import HammerAgent
import HammerAgentCore
import XCTest

extension HammerAgent {
    /// Runs a command through the agent's HTTP endpoint, like the command line tool does.
    func run(_ command: String, _ arguments: [String: JSONValue] = [:]) async throws -> (Data, Int) {
        return try await self.request("POST", AgentEndpoint.commandPath(command),
                                      body: try JSONEncoder().encode(arguments))
    }

    func request(_ method: String, _ path: String, body: Data? = nil) async throws -> (Data, Int) {
        let port = try XCTUnwrap(self.port)
        var request = URLRequest(url: try XCTUnwrap(URL(string: "http://127.0.0.1:\(port)\(path)")))
        request.httpMethod = method
        request.httpBody = body
        let (data, response) = try await URLSession.shared.data(for: request)
        return (data, try XCTUnwrap(response as? HTTPURLResponse).statusCode)
    }
}
