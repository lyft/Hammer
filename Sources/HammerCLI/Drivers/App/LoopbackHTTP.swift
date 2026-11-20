import Foundation
#if canImport(Glibc)
import Glibc
#endif

/// A minimal HTTP/1.1 client for the agent's server on the loopback interface.
///
/// Each CLI command makes one or two requests, and URLSession's first request in a process takes tens of
/// milliseconds to set up, more than the request itself, so a plain socket answers sooner.
enum LoopbackHTTP {
    struct Response {
        let status: Int
        let headers: [String: String]
        let body: Data

        /// The header's value, matching its name in any case.
        func header(_ name: String) -> String? {
            return self.headers[name.lowercased()]
        }
    }

    /// The status line and headers, and where the body starts in the bytes received.
    private struct Head {
        let status: Int
        let headers: [String: String]
        let bodyStart: Int

        var length: Int? {
            return self.headers["content-length"].flatMap(Int.init)
        }
    }

    enum Failure: Error {
        case unreachable
        case disconnected
        case timedOut
        case invalidResponse
    }

    /// Sends a request to the port on 127.0.0.1 and reads the whole response.
    ///
    /// - parameter request: The request, whose URL's path, method, headers, body and timeout it sends. The
    ///                      timeout is the longest wait for the server, while connecting, sending or reading.
    /// - parameter port:    The port.
    ///
    /// - throws: A `Failure` if the server can't be reached, closes the connection early or is too slow.
    ///
    /// - returns: The response.
    static func send(_ request: URLRequest, port: UInt16) async throws -> Response {
        let body = request.httpBody ?? Data()
        let headers = (request.allHTTPHeaderFields ?? [:]).map { "\($0.key): \($0.value)" }
        let head = [
            "\(request.httpMethod ?? "GET") \(request.url?.path ?? "/") HTTP/1.1",
            "Host: 127.0.0.1:\(port)",
            "Content-Length: \(body.count)",
            "Connection: close",
        ] + headers
        let data = Data((head.joined(separator: "\r\n") + "\r\n\r\n").utf8) + body
        let deadline = Date(timeIntervalSinceNow: request.timeoutInterval)
        // The calls block, so they run off the cooperative thread pool
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(with: Result { try self.exchange(data, port: port, deadline: deadline) })
            }
        }
    }

    private static func exchange(_ request: Data, port: UInt16, deadline: Date) throws -> Response {
        let socket = try self.connect(port: port)
        defer { close(socket) }
        try self.write(request, to: socket, deadline: deadline)
        return try self.readResponse(from: socket, deadline: deadline)
    }

    private static func connect(port: UInt16) throws -> Int32 {
        #if canImport(Glibc)
        let socket = Glibc.socket(AF_INET, Int32(SOCK_STREAM.rawValue), 0)
        #else
        let socket = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        #endif
        guard socket >= 0 else {
            throw Failure.unreachable
        }

        #if !canImport(Glibc)
        // A server that closes early raises SIGPIPE on the next write, which would end the process
        var on: Int32 = 1
        setsockopt(socket, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))
        #endif
        var address = sockaddr_in()
        #if !canImport(Glibc)
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        #endif
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = port.bigEndian
        address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))
        let result = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                #if canImport(Glibc)
                Glibc.connect(socket, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                #else
                Darwin.connect(socket, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                #endif
            }
        }

        guard result == 0 else {
            close(socket)
            throw Failure.unreachable
        }

        return socket
    }

    private static func write(_ data: Data, to socket: Int32, deadline: Date) throws {
        #if canImport(Glibc)
        let flags = Int32(MSG_NOSIGNAL)
        #else
        let flags: Int32 = 0
        #endif
        var sent = 0
        while sent < data.count {
            try self.wait(for: socket, events: Int16(POLLOUT), deadline: deadline)
            let count = data.withUnsafeBytes { bytes in
                #if canImport(Glibc)
                Glibc.send(socket, bytes.baseAddress! + sent, data.count - sent, flags)
                #else
                Darwin.send(socket, bytes.baseAddress! + sent, data.count - sent, flags)
                #endif
            }
            guard count > 0 else {
                throw Failure.disconnected
            }

            sent += count
        }
    }

    /// Reads until the body has its `Content-Length`, or until the server closes the connection.
    private static func readResponse(from socket: Int32, deadline: Date) throws -> Response {
        var received = Data()
        var buffer = [UInt8](repeating: 0, count: 64 << 10)
        var head: Head?
        while true {
            if let head, let length = head.length, received.count - head.bodyStart >= length {
                break
            }

            try self.wait(for: socket, events: Int16(POLLIN), deadline: deadline)
            let count = read(socket, &buffer, buffer.count)
            if count < 0 && errno == EINTR {
                continue
            }

            guard count > 0 else {
                // The server closed the connection, which ends a response without a length
                guard head != nil else {
                    throw Failure.disconnected
                }

                break
            }

            received.append(buffer, count: count)
            if head == nil {
                head = try self.parseHead(received)
            }
        }

        guard let head else {
            throw Failure.disconnected
        }

        let end = head.length.map { min(head.bodyStart + $0, received.count) } ?? received.count
        if let length = head.length, end - head.bodyStart < length {
            throw Failure.disconnected
        }

        return Response(status: head.status, headers: head.headers,
                        body: received.subdata(in: head.bodyStart..<end))
    }

    /// Parses the status line and headers once they've all arrived, or returns nil to read more.
    private static func parseHead(_ data: Data) throws -> Head? {
        guard let separator = data.range(of: Data("\r\n\r\n".utf8)) else {
            return nil
        }

        guard let text = String(bytes: data[data.startIndex..<separator.lowerBound], encoding: .utf8) else {
            throw Failure.invalidResponse
        }

        var lines = text.components(separatedBy: "\r\n")
        let statusLine = lines.removeFirst().split(separator: " ")
        guard statusLine.count >= 2, statusLine[0].hasPrefix("HTTP/"), let status = Int(statusLine[1]) else {
            throw Failure.invalidResponse
        }

        var headers = [String: String]()
        for line in lines {
            guard let colon = line.firstIndex(of: ":") else {
                continue
            }

            let name = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            headers[name] = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        }

        return Head(status: status, headers: headers, bodyStart: separator.upperBound - data.startIndex)
    }

    private static func wait(for socket: Int32, events: Int16, deadline: Date) throws {
        while true {
            let remaining = deadline.timeIntervalSinceNow
            guard remaining > 0 else {
                throw Failure.timedOut
            }

            var descriptor = pollfd(fd: socket, events: events, revents: 0)
            let result = poll(&descriptor, 1, Int32(min(remaining * 1000, Double(Int32.max)).rounded(.up)))
            if result > 0 {
                return
            } else if result == 0 {
                throw Failure.timedOut
            } else if errno != EINTR {
                throw Failure.disconnected
            }
        }
    }
}
