import Foundation
import HammerAgentCore

/// A Model Context Protocol server over standard input and output that exposes the app's commands as tools.
///
/// Tools are listed from the app when it is running, so the commands it registers appear as tools, and
/// from the builtin commands when it is not, so the client can start before the app.
struct MCPServer {
    private static let instructions = """
        Drives the iOS app that runs Hammer's agent, from inside the app. Call describe to find elements \
        and target them by identifier, label, value or traits rather than coordinates. Every gesture \
        waits for the app to process it; use wait_for after one that starts a transition.
        """

    let client: AgentClient

    func run() async throws {
        for try await line in FileHandle.standardInput.bytes.lines where !line.isEmpty {
            let message = try? JSONDecoder().decode([String: JSONValue].self, from: Data(line.utf8))
            guard let message else {
                let error: JSONValue = ["code": -32700, "message": "Parse error"]
                self.write(["jsonrpc": "2.0", "id": .null, "error": error])
                continue
            }

            // Notifications have no id and need no response
            guard let id = message["id"], case .string(let method) = message["method"] else {
                continue
            }

            let params = message["params"]?.objectValue ?? [:]
            do {
                let result = try await self.respond(to: method, params: params)
                self.write(["jsonrpc": "2.0", "id": id, "result": result])
            } catch let error as MCPError {
                let body: JSONValue = ["code": .number(Double(error.code)), "message": .string(error.message)]
                self.write(["jsonrpc": "2.0", "id": id, "error": body])
            }
        }
    }

    private func respond(to method: String, params: [String: JSONValue]) async throws -> JSONValue {
        switch method {
        case "initialize":
            return [
                // The server only uses the tools and messages common to every version
                "protocolVersion": params["protocolVersion"] ?? "2025-06-18",
                "capabilities": ["tools": [:]],
                "serverInfo": ["name": "hammer", "version": "1.0.0"],
                "instructions": .string(Self.instructions),
            ]
        case "ping":
            return [:]
        case "tools/list":
            let tools = await self.client.commandsOrBuiltins().map { command -> JSONValue in
                [
                    "name": .string(command.name),
                    "description": .string(command.summary),
                    "inputSchema": command.argumentsSchema,
                ]
            }
            return ["tools": .array(tools)]
        case "tools/call":
            guard case .string(let name) = params["name"] else {
                throw MCPError(code: -32602, message: "Missing tool name")
            }

            return await self.callTool(name, arguments: params["arguments"]?.objectValue ?? [:])
        default:
            throw MCPError(code: -32601, message: "Method not found: \(method)")
        }
    }

    private func callTool(_ name: String, arguments: [String: JSONValue]) async -> JSONValue {
        let output: Data
        do {
            output = try await self.client.run(name, arguments: arguments)
        } catch {
            let content: JSONValue = ["type": "text", "text": .string(String(describing: error))]
            return ["content": [content], "isError": true]
        }

        if let image = try? JSONDecoder().decode(AgentImage.self, from: output) {
            let content: JSONValue = [
                "type": "image",
                "data": .string(image.data.base64EncodedString()),
                "mimeType": .string(image.mimeType),
            ]
            return ["content": [content]]
        }

        let text = String(bytes: output, encoding: .utf8) ?? ""
        return ["content": [["type": "text", "text": .string(text == "{}" ? "Done" : text)]]]
    }

    private func write(_ message: JSONValue) {
        guard let data = try? JSONEncoder().encode(message) else {
            return
        }

        FileHandle.standardOutput.write(data + Data("\n".utf8))
    }
}

private struct MCPError: Error {
    let code: Int
    let message: String
}
