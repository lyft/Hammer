import HammerAgent
import HammerAgentCore
import XCTest

extension HammerAgent {
    /// Runs a command through the agent's HTTP endpoint, like the command line tool does.
    func run(_ command: String, _ arguments: [String: JSONValue] = [:]) async throws -> (Data, Int) {
        return try await self.request("POST", AgentEndpoint.commandPath(command),
                                      body: try JSONEncoder().encode(arguments),
                                      headers: ["Content-Type": "application/json"])
    }

    func request(_ method: String, _ path: String, body: Data? = nil, headers: [String: String] = [:])
        async throws -> (Data, Int)
    {
        let port = try XCTUnwrap(self.port)
        var request = URLRequest(url: try XCTUnwrap(URL(string: "http://127.0.0.1:\(port)\(path)")))
        request.httpMethod = method
        request.httpBody = body
        request.allHTTPHeaderFields = headers
        let (data, response) = try await URLSession.shared.data(for: request)
        return (data, try XCTUnwrap(response as? HTTPURLResponse).statusCode)
    }

    /// Sends the request head as is, for headers URLSession does not let clients set, such as `Host`.
    ///
    /// - parameter head: The request line and headers, without the blank line that ends them.
    ///
    /// - returns: The status code of the response.
    func rawRequest(_ head: String) async throws -> Int {
        let port = Int(try XCTUnwrap(self.port))
        let task = URLSession.shared.streamTask(withHostName: "127.0.0.1", port: port)
        task.resume()
        defer { task.cancel() }

        try await task.write(Data((head + "\r\n\r\n").utf8), timeout: 5)
        let (data, _) = try await task.readData(ofMinLength: 12, maxLength: 4096, timeout: 5)
        let response = try XCTUnwrap(String(bytes: try XCTUnwrap(data), encoding: .utf8))
        return try XCTUnwrap(Int(response.split(separator: " ")[1]))
    }
}
