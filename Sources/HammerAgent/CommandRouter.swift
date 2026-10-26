import Foundation
import HammerAgentCore

/// Routes requests to the registered commands and runs them one at a time, so gestures never interleave.
@MainActor
final class CommandRouter {
    private struct Registration {
        let descriptor: CommandDescriptor
        let run: @MainActor ([String: JSONValue], AgentContext) async throws -> Data
    }

    private var registrations = [String: Registration]()
    private var order = [String]()
    private var lastRun: Task<Void, Never>?
    private let references = ObjectReferences()
    private let changes = ChangeLog()

    var descriptors: [CommandDescriptor] {
        return self.order.compactMap { self.registrations[$0]?.descriptor }
    }

    func register<Command: AgentCommand>(_ command: Command) {
        let name = command.descriptor.name
        let names = command.descriptor.parameters.map(\.name)
        let reserved = names.filter(CommandDescriptor.reservedParameterNames.contains)
        precondition(reserved.isEmpty, "Command \(name) uses reserved parameter names: \(reserved)")
        precondition(Set(names).count == names.count, "Command \(name) has duplicate parameters: \(names)")
        if self.registrations[name] == nil {
            self.order.append(name)
        }

        let descriptor = command.descriptor
        self.registrations[name] = Registration(descriptor: descriptor) { object, context in
            let arguments = try JSONValue.object(object).decode(as: Command.Arguments.self)
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            return try encoder.encode(try await command.run(arguments, in: context))
        }
    }

    func respond(to request: HTTPRequest) async -> HTTPResponse {
        switch (request.method, request.path) {
        case ("GET", AgentEndpoint.commandsPath):
            return HTTPResponse(status: 200, body: (try? JSONEncoder().encode(self.descriptors)) ?? Data())
        case ("POST", let path) where path.hasPrefix(AgentEndpoint.commandPath("")):
            let name = String(path.dropFirst(AgentEndpoint.commandPath("").count))
            guard let registration = self.registrations[name] else {
                let suggestion = closestMatch(to: name, in: self.order).map { ", did you mean \($0)?" } ?? ""
                return HTTPResponse(status: 404, code: .unknownCommand,
                                    error: "Unknown command \"\(name)\"\(suggestion)",
                                    hint: "The commands are \(self.order.joined(separator: ", "))")
            }

            let context = AgentContext(references: self.references, changes: self.changes)
            return await self.serially { await Self.run(registration, body: request.body, in: context) }
        default:
            return HTTPResponse(status: 404, code: .invalidRequest,
                                error: "Unknown route \(request.method) \(request.path)")
        }
    }

    private static func run(_ registration: Registration, body: Data,
                            in context: AgentContext) async -> HTTPResponse
    {
        let descriptor = registration.descriptor
        do {
            // Arguments are checked against the descriptor first, so every command reports mistakes the same
            let arguments = try Self.argumentsObject(from: body, for: descriptor)
            try descriptor.validate(arguments)
            let output = try await registration.run(arguments, context)
            try await context.finish()
            return HTTPResponse(status: 200, body: output)
        } catch {
            try? await context.finish()
            return ErrorReport(error, for: descriptor).response
        }
    }

    private static func argumentsObject(from body: Data, for descriptor: CommandDescriptor) throws
        -> [String: JSONValue]
    {
        guard !body.isEmpty else {
            return [:]
        }

        guard let object = try? JSONDecoder().decode([String: JSONValue].self, from: body) else {
            throw ArgumentsError("The arguments must be a JSON object", hint: descriptor.argumentsHint)
        }

        return object
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
