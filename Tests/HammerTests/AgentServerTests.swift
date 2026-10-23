import HammerAgent
import XCTest

@MainActor
final class AgentServerTests: XCTestCase {
    func testServesRequestsWhenAllowingRemoteConnections() async throws {
        let agent = HammerAgent(port: 0, token: "secret")
        try await agent.start(allowsRemoteConnections: true)
        defer { agent.stop() }

        let (_, status) = try await agent.request("GET", AgentEndpoint.commandsPath,
                                                  headers: ["Authorization": "Bearer secret"])
        XCTAssertEqual(status, 200)
    }

    func testRefusesRemoteConnectionsWithoutToken() async throws {
        let agent = HammerAgent(port: 0, token: nil)
        do {
            try await agent.start(allowsRemoteConnections: true)
            XCTFail("Expected the agent to refuse to start")
        } catch AgentStartError.remoteConnectionsWithoutToken {
            XCTAssertNil(agent.port)
        }
    }

    func testRequiresToken() async throws {
        let agent = HammerAgent(port: 0, token: "secret")
        try await agent.start()
        defer { agent.stop() }

        for (authorization, expectedStatus) in [(nil, 401), ("Bearer wrong!", 401), ("Bearer secret", 200)] {
            let headers = authorization.map { ["Authorization": $0] } ?? [:]
            let (data, status) = try await agent.request("GET", AgentEndpoint.commandsPath, headers: headers)
            XCTAssertEqual(status, expectedStatus, String(bytes: data, encoding: .utf8) ?? "")
        }
    }

    func testRejectsBrowserRequests() async throws {
        let agent = HammerAgent(port: 0, token: nil)
        try await agent.start()
        defer { agent.stop() }

        let body = try JSONEncoder().encode([String: JSONValue]())
        let path = AgentEndpoint.commandPath("describe")
        let (_, originStatus) = try await agent.request(
            "POST", path, body: body,
            headers: ["Content-Type": "application/json", "Origin": "https://example.com"])
        XCTAssertEqual(originStatus, 403)

        let (_, formStatus) = try await agent.request("POST", path, body: body,
                                                      headers: ["Content-Type": "text/plain"])
        XCTAssertEqual(formStatus, 415)

        let port = try XCTUnwrap(agent.port)
        let rebinding = try await agent.rawRequest("GET /commands HTTP/1.1\r\nHost: example.com:\(port)")
        XCTAssertEqual(rebinding, 403)
        let address = try await agent.rawRequest("GET /commands HTTP/1.1\r\nHost: 127.0.0.1:\(port)")
        XCTAssertEqual(address, 200)
    }
}
