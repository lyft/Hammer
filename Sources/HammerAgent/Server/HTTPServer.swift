import Foundation
import HammerAgentCore
import Network

struct HTTPRequest: Sendable {
    let method: String
    let path: String
    /// The headers, by lowercased name.
    let headers: [String: String]
    let body: Data
}

struct HTTPResponse: Sendable {
    let status: Int
    let body: Data

    init(status: Int, body: Data) {
        self.status = status
        self.body = body
    }

    init(status: Int, error: String, hint: String? = nil) {
        let body = AgentErrorBody(error: error, hint: hint)
        self.init(status: status, body: (try? JSONEncoder().encode(body)) ?? Data())
    }

    var serialized: Data {
        let reason = HTTPURLResponse.localizedString(forStatusCode: self.status).capitalized
        let head = [
            "HTTP/1.1 \(self.status) \(reason)",
            "Content-Type: application/json",
            "Content-Length: \(self.body.count)",
            "Connection: close",
        ]
        return Data((head.joined(separator: "\r\n") + "\r\n\r\n").utf8) + self.body
    }
}

/// A minimal HTTP/1.1 server that handles one request per connection.
final class HTTPServer: Sendable {
    typealias Handler = @Sendable (HTTPRequest) async -> HTTPResponse

    private static let maxRequestSize = 16 << 20

    private let listener: NWListener
    private let queue = DispatchQueue(label: "com.lyft.hammer.agent.server")
    private let token: String?
    private let handler: Handler

    /// Creates a server bound to the loopback interface, or to every interface.
    ///
    /// - parameter port:                    The port to listen on, or 0 for any free port.
    /// - parameter allowsRemoteConnections: If other devices on the network can connect.
    /// - parameter token:                   The token requests must send, or nil for none.
    /// - parameter handler:                 Responds to each request.
    init(port: UInt16, allowsRemoteConnections: Bool, token: String?, handler: @escaping Handler) throws {
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        let port = NWEndpoint.Port(rawValue: port) ?? .any
        if allowsRemoteConnections {
            self.listener = try NWListener(using: parameters, on: port)
        } else {
            parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: port)
            self.listener = try NWListener(using: parameters)
        }

        self.token = token
        self.handler = handler
    }

    deinit {
        self.listener.cancel()
    }

    /// The port the server listens on, once it started.
    var port: UInt16? {
        return self.listener.port?.rawValue
    }

    /// Starts listening.
    ///
    /// - throws: The listener's error if it could not start.
    func start() async throws {
        self.listener.newConnectionHandler = { [weak self] connection in
            guard let self else {
                connection.cancel()
                return
            }

            Task { await self.serve(connection) }
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let resume = OneShot(continuation)
            self.listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    resume(.success(()))
                case .failed(let error), .waiting(let error):
                    resume(.failure(error))
                case .cancelled:
                    resume(.failure(CancellationError()))
                default:
                    break
                }
            }

            self.listener.start(queue: self.queue)
        }
    }

    /// Stops listening. Requests in progress still finish.
    func stop() {
        self.listener.cancel()
    }

    private func serve(_ connection: NWConnection) async {
        connection.start(queue: self.queue)
        defer { connection.cancel() }

        let response: HTTPResponse
        do {
            let request = try await connection.receiveRequest(limit: Self.maxRequestSize)
            if let rejection = self.rejection(of: request) {
                response = rejection
            } else {
                response = await self.handler(request)
            }
        } catch let error as HTTPRequestError {
            response = HTTPResponse(status: 400, error: error.message)
        } catch {
            return
        }

        try? await connection.sendAll(response.serialized)
    }
}

extension HTTPServer {
    /// Rejects requests from web pages, since browsers let any site send them to the loopback interface.
    ///
    /// - parameter request: The request.
    ///
    /// - returns: The response for a rejected request, or nil if the request is allowed.
    fileprivate func rejection(of request: HTTPRequest) -> HTTPResponse? {
        if request.headers["origin"] != nil || request.headers["sec-fetch-site"] != nil {
            return HTTPResponse(status: 403, error: "Requests from web browsers are not allowed",
                                hint: "Use the hammer command line tool, or a client that is not a browser")
        }

        // A domain name means a site may have resolved its own domain to this device
        if let host = request.headers["host"], !Self.isAddress(host: host) {
            return HTTPResponse(status: 403, error: "Requests for host \(host) are not allowed",
                                hint: "Connect with an IP address such as 127.0.0.1, or localhost")
        }

        if let token = self.token, !Self.isAuthorized(request.headers["authorization"], token: token) {
            return HTTPResponse(status: 401, error: "The request is missing the agent's token",
                                hint: """
                Set \(AgentEndpoint.tokenEnvironmentKey) to the token the app was started with, or send it \
                as Authorization: Bearer <token>
                """)
        }

        // Browsers only send JSON after a preflight request, which the server never allows
        let contentType = request.headers["content-type"]?.split(separator: ";").first?
            .trimmingCharacters(in: .whitespaces).lowercased()
        if request.method == "POST" && contentType != "application/json" {
            return HTTPResponse(status: 415, error: "Requests must have the content type application/json",
                                hint: "Send the header Content-Type: application/json")
        }

        return nil
    }

    /// Compares every byte so the time taken does not reveal how much of the token matched.
    private static func isAuthorized(_ authorization: String?, token: String) -> Bool {
        let expected = Array("Bearer \(token)".utf8)
        let actual = Array((authorization ?? "").utf8)
        guard actual.count == expected.count else {
            return false
        }

        return zip(actual, expected).reduce(0) { $0 | ($1.0 ^ $1.1) } == 0
    }

    private static func isAddress(host: String) -> Bool {
        if host.hasPrefix("[") {
            return IPv6Address(String(host.dropFirst().prefix { $0 != "]" })) != nil
        }

        let name = String(host.split(separator: ":", maxSplits: 1).first ?? "")
        return name == "localhost" || IPv4Address(name) != nil
    }
}

private struct HTTPRequestError: Error {
    let message: String
}

/// Resumes a continuation the first time it is called, since listeners report states after `ready`.
private final class OneShot: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Error>?

    init(_ continuation: CheckedContinuation<Void, Error>) {
        self.continuation = continuation
    }

    func callAsFunction(_ result: Result<Void, Error>) {
        let continuation = self.lock.withLock {
            defer { self.continuation = nil }
            return self.continuation
        }

        continuation?.resume(with: result)
    }
}

extension NWConnection {
    fileprivate func receiveRequest(limit: Int) async throws -> HTTPRequest {
        let separator = Data("\r\n\r\n".utf8)
        var buffer = Data()
        while buffer.range(of: separator) == nil {
            guard buffer.count < limit, let chunk = try await self.receiveChunk() else {
                throw HTTPRequestError(message: "Incomplete request head")
            }

            buffer.append(chunk)
        }

        guard let headEnd = buffer.range(of: separator),
              let head = String(data: buffer[..<headEnd.lowerBound], encoding: .utf8)
        else {
            throw HTTPRequestError(message: "Invalid request head")
        }

        let lines = head.components(separatedBy: "\r\n")
        let requestLine = lines[0].split(separator: " ")
        guard requestLine.count == 3 else {
            throw HTTPRequestError(message: "Invalid request line")
        }

        var headers = [String: String]()
        for line in lines.dropFirst() {
            let parts = line.split(separator: ":", maxSplits: 1)
            if parts.count == 2 {
                headers[parts[0].lowercased()] = parts[1].trimmingCharacters(in: .whitespaces)
            }
        }

        let contentLength = headers["content-length"].flatMap { Int($0) } ?? 0

        guard contentLength <= limit else {
            throw HTTPRequestError(message: "Request body is too large")
        }

        var body = buffer[headEnd.upperBound...]
        while body.count < contentLength {
            guard let chunk = try await self.receiveChunk() else {
                throw HTTPRequestError(message: "Incomplete request body")
            }

            body.append(chunk)
        }

        return HTTPRequest(method: String(requestLine[0]), path: String(requestLine[1]), headers: headers,
                           body: Data(body.prefix(contentLength)))
    }

    /// Receives the next data, or nil once the client closed the connection.
    private func receiveChunk() async throws -> Data? {
        return try await withCheckedThrowingContinuation { continuation in
            self.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { data, _, isComplete, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let data, !data.isEmpty {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(returning: isComplete ? nil : Data())
                }
            }
        }
    }

    fileprivate func sendAll(_ data: Data) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.send(content: data, isComplete: true, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
    }
}
