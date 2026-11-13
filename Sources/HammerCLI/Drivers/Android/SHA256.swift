import Foundation

/// SHA-256, to compare the helper APK on a device with the tool's. Foundation has no hash on Linux, and the
/// digest needs no other dependency.
enum SHA256 {
    static func hex(_ data: Data) -> String {
        return self.digest(data).map { String(format: "%02x", $0) }.joined()
    }

    static func digest(_ data: Data) -> [UInt8] {
        var hash: [UInt32] = [
            0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
        ]
        var message = [UInt8](data)
        let bitLength = UInt64(message.count) * 8
        message.append(0x80)
        while message.count % 64 != 56 {
            message.append(0)
        }
        message += (0..<8).reversed().map { UInt8(truncatingIfNeeded: bitLength >> (UInt64($0) * 8)) }

        var words = [UInt32](repeating: 0, count: 64)
        for chunk in stride(from: 0, to: message.count, by: 64) {
            for index in 0..<16 {
                let offset = chunk + index * 4
                words[index] = UInt32(message[offset]) << 24 | UInt32(message[offset + 1]) << 16
                    | UInt32(message[offset + 2]) << 8 | UInt32(message[offset + 3])
            }
            for index in 16..<64 {
                let s0 = words[index - 15].rotatedRight(7) ^ words[index - 15].rotatedRight(18)
                    ^ (words[index - 15] >> 3)
                let s1 = words[index - 2].rotatedRight(17) ^ words[index - 2].rotatedRight(19)
                    ^ (words[index - 2] >> 10)
                words[index] = words[index - 16] &+ s0 &+ words[index - 7] &+ s1
            }

            var (a, b, c, d) = (hash[0], hash[1], hash[2], hash[3])
            var (e, f, g, h) = (hash[4], hash[5], hash[6], hash[7])
            for index in 0..<64 {
                let s1 = e.rotatedRight(6) ^ e.rotatedRight(11) ^ e.rotatedRight(25)
                let choice = (e & f) ^ (~e & g)
                let temp1 = h &+ s1 &+ choice &+ self.constants[index] &+ words[index]
                let s0 = a.rotatedRight(2) ^ a.rotatedRight(13) ^ a.rotatedRight(22)
                let majority = (a & b) ^ (a & c) ^ (b & c)
                let temp2 = s0 &+ majority
                (h, g, f, e, d, c, b, a) = (g, f, e, d &+ temp1, c, b, a, temp1 &+ temp2)
            }

            for (index, value) in [a, b, c, d, e, f, g, h].enumerated() {
                hash[index] = hash[index] &+ value
            }
        }

        return hash.flatMap { word in (0..<4).reversed().map { UInt8(truncatingIfNeeded: word >> ($0 * 8)) } }
    }

    private static let constants: [UInt32] = [
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
    ]
}

private extension UInt32 {
    func rotatedRight(_ count: UInt32) -> UInt32 {
        return (self >> count) | (self << (32 - count))
    }
}
