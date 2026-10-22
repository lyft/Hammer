import Foundation
import HammerAgentCore

/// Routes requests to the registered commands and runs them one at a time, so gestures never interleave.
@MainActor
final class CommandRouter {
    private struct Registration {
        let descriptor: CommandDescriptor
        let run: @MainActor (Data, AgentContext) async throws -> Data
    }

    private var registrations = [String: Registration]()
    private var order = [String]()
    private var lastRun: Task<Void, Never>?

    var descriptors: [CommandDescriptor] {
        return self.order.compactMap { self.registrations[$0]?.descriptor }
    }

    func register<Command: AgentCommand>(_ command: Command) {
        let name = command.descriptor.name
        if self.registrations[name] == nil {
            self.order.append(name)
        }

        let descriptor = command.descriptor
        self.registrations[name] = Registration(descriptor: descriptor) { body, context in
            let arguments = try Self.decodeArguments(Command.Arguments.self, from: body, for: descriptor)
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            return try encoder.encode(try await command.run(arguments, in: context))
        }
    }

    /// Decodes the arguments, rejecting the ones the command does not declare so typos are not ignored.
    private static func decodeArguments<Arguments: Decodable>(_ type: Arguments.Type, from body: Data,
                                                              for descriptor: CommandDescriptor) throws
        -> Arguments
    {
        do {
            let object = body.isEmpty ? [:] : try JSONDecoder().decode([String: JSONValue].self, from: body)
            let names = Set(descriptor.parameters.map(\.name))
            if let unknown = object.keys.sorted().first(where: { !names.contains($0) }) {
                throw AgentError.invalidArguments("Unknown argument \"\(unknown)\"")
            }

            return try JSONValue.object(object).decode(as: type)
        } catch let error as DecodingError {
            throw AgentError.invalidArguments(error.argumentsMessage)
        }
    }

    func respond(to request: HTTPRequest) async -> HTTPResponse {
        switch (request.method, request.path) {
        case ("GET", AgentEndpoint.commandsPath):
            return HTTPResponse(status: 200, body: (try? JSONEncoder().encode(self.descriptors)) ?? Data())
        case ("POST", let path) where path.hasPrefix(AgentEndpoint.commandPath("")):
            let name = String(path.dropFirst(AgentEndpoint.commandPath("").count))
            guard let registration = self.registrations[name] else {
                return HTTPResponse(status: 404, error: "Unknown command \"\(name)\"")
            }

            return await self.serially { await Self.run(registration, body: request.body) }
        default:
            return HTTPResponse(status: 404, error: "Unknown route \(request.method) \(request.path)")
        }
    }

    private static func run(_ registration: Registration, body: Data) async -> HTTPResponse {
        let context = AgentContext()
        do {
            let output = try await registration.run(body, context)
            try await context.finish()
            return HTTPResponse(status: 200, body: output)
        } catch {
            try? await context.finish()
            let status = if case AgentError.invalidArguments = error { 400 } else { 500 }
            return HTTPResponse(status: status, error: String(describing: error))
        }
    }

    private func serially(_ operation: @escaping @MainActor () async -> HTTPResponse) async -> HTTPResponse {
        let previous = self.lastRun
        let task = Task {
            await previous?.value
            return await operation()
        }

        self.lastRun = Task { _ = await task.value }
        return await task.value
    }
}

extension DecodingError {
    fileprivate var argumentsMessage: String {
        switch self {
        case .keyNotFound(let key, _):
            return "Missing argument \"\(key.stringValue)\""
        case .typeMismatch(_, let context), .valueNotFound(_, let context):
            let name = context.codingPath.map(\.stringValue).joined(separator: ".")
            return "Invalid argument \"\(name)\": \(context.debugDescription)"
        case .dataCorrupted(let context) where context.codingPath.isEmpty:
            return "The arguments must be a JSON object: \(context.debugDescription)"
        case .dataCorrupted(let context):
            let name = context.codingPath.map(\.stringValue).joined(separator: ".")
            return "Invalid argument \"\(name)\": \(context.debugDescription)"
        @unknown default:
            return String(describing: self)
        }
    }
}
