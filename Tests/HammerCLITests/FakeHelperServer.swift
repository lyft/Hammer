import Foundation
@testable import HammerCLI
#if canImport(Glibc)
import Glibc
#endif

/// A helper on 127.0.0.1 that answers `version` with `version`, proving `proofKey` in each response, or a
/// process that took the helper's socket when it proves nothing.
final class FakeHelperServer: @unchecked Sendable {
    let port: UInt16
    private let descriptor: Int32
    private let version: String
    private let proofKey: @Sendable () -> Data?
    private let onRequest: @Sendable (String) -> Void
    private let lock = NSLock()
    private var requests: [(path: String, body: String)] = []

    /// - parameter proofKey: The key to prove at each request, or nil to prove nothing.
    init(version: String, proofKey: @escaping @Sendable () -> Data?,
         onRequest: @escaping @Sendable (String) -> Void = { _ in }) throws
    {
        self.version = version
        self.proofKey = proofKey
        self.onRequest = onRequest
        #if canImport(Glibc)
        let descriptor = socket(AF_INET, Int32(SOCK_STREAM.rawValue), 0)
        #else
        let descriptor = socket(AF_INET, SOCK_STREAM, 0)
        #endif
        var address = sockaddr_in()
        #if canImport(Darwin)
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        #endif
        address.sin_family = sa_family_t(AF_INET)
        address.sin_addr.s_addr = inet_addr("127.0.0.1")
        var size = socklen_t(MemoryLayout<sockaddr_in>.size)
        let bound = withUnsafeMutablePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { address in
                bind(descriptor, address, size) == 0 && listen(descriptor, 8) == 0
                    && getsockname(descriptor, address, &size) == 0
            }
        }
        guard bound else {
            close(descriptor)
            throw POSIXError(.EADDRINUSE)
        }

        self.descriptor = descriptor
        self.port = UInt16(bigEndian: address.sin_port)
        Thread.detachNewThread { [self] in self.serve() }
    }

    /// The paths of the requests it answered.
    var paths: [String] {
        return self.lock.withLock { self.requests.map(\.path) }
    }

    /// The bodies of the requests it answered.
    var bodies: [String] {
        return self.lock.withLock { self.requests.map(\.body) }
    }

    private func serve() {
        while true {
            let connection = accept(self.descriptor, nil, nil)
            guard connection >= 0 else {
                return
            }

            self.answer(connection)
            close(connection)
        }
    }

    private func answer(_ connection: Int32) {
        var received = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while !Self.isComplete(received) {
            let count = read(connection, &buffer, buffer.count)
            guard count > 0 else {
                return
            }

            received.append(contentsOf: buffer[0..<count])
        }

        let request = String(bytes: received, encoding: .utf8) ?? ""
        let lines = request.components(separatedBy: "\r\n")
        let path = lines.first?.split(separator: " ").dropFirst().first.map(String.init) ?? ""
        let body = request.components(separatedBy: "\r\n\r\n").dropFirst().joined(separator: "\r\n\r\n")
        self.lock.withLock { self.requests.append((path, body)) }
        self.onRequest(path)
        let challenge = lines.first { $0.lowercased().hasPrefix("x-hammer-challenge:") }
            .map { $0.split(separator: ":", maxSplits: 1)[1].trimmingCharacters(in: .whitespaces) }
        let response = path.hasSuffix("/version") ? #"{"version":"\#(self.version)"}"# : "{}"
        var head = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n"
        head += "Content-Length: \(response.utf8.count)\r\n"
        if let key = self.proofKey(), let challenge {
            head += "X-Hammer-Proof: \(SHA256.hmacHex(key: key, message: Data(challenge.utf8)))\r\n"
        }
        let bytes = Array((head + "Connection: close\r\n\r\n" + response).utf8)
        _ = bytes.withUnsafeBytes { write(connection, $0.baseAddress, bytes.count) }
    }

    private static func isComplete(_ data: Data) -> Bool {
        let text = String(bytes: data, encoding: .utf8) ?? ""
        guard let end = text.range(of: "\r\n\r\n") else {
            return false
        }

        let length = text[..<end.lowerBound].components(separatedBy: "\r\n")
            .first { $0.lowercased().hasPrefix("content-length:") }
            .flatMap { Int($0.split(separator: ":")[1].trimmingCharacters(in: .whitespaces)) } ?? 0
        return text[end.upperBound...].utf8.count >= length
    }

    deinit {
        shutdown(self.descriptor, Int32(SHUT_RDWR))
        close(self.descriptor)
    }
}
