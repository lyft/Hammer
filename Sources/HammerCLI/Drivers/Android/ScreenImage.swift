import CZlib
import Foundation

/// The pixels of an Android screen capture, cropped, scaled and encoded as PNG without platform image
/// libraries, so the system driver runs wherever `hammer` builds.
struct ScreenImage: Equatable {
    let width: Int
    let height: Int

    /// RGBA, 4 bytes per pixel, row by row.
    let pixels: [UInt8]

    /// Reads the output of `screencap` without `-p`: the width, height and pixel format as 32-bit little
    /// endian integers, then a color space on Android 12 and later, then the pixels.
    init(screencap data: Data) throws {
        let bytes = [UInt8](data)
        func field(_ index: Int) -> Int {
            let offset = index * 4
            return bytes[offset..<offset + 4].enumerated()
                .reduce(0) { $0 | Int($1.element) << (8 * $1.offset) }
        }

        guard bytes.count >= 12 else {
            throw ScreenImageError.unreadable("screencap returned \(bytes.count) bytes")
        }

        let width = field(0)
        let height = field(1)
        let format = field(2)
        let header = bytes.count - width * height * 4
        // 1 is RGBA_8888, the format every device captures the screen in
        guard width > 0, height > 0, format == 1, header == 12 || header == 16 else {
            throw ScreenImageError.unreadable("screencap returned a \(width)x\(height) capture in format " +
                                              "\(format) with \(bytes.count) bytes")
        }

        self.init(width: width, height: height, pixels: Array(bytes[header...]))
    }

    init(width: Int, height: Int, pixels: [UInt8]) {
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    /// The pixels inside the rectangle, which must be inside the image.
    func cropped(x: Int, y: Int, width: Int, height: Int) -> ScreenImage {
        var pixels = [UInt8]()
        pixels.reserveCapacity(width * height * 4)
        for row in y..<y + height {
            let start = (row * self.width + x) * 4
            pixels += self.pixels[start..<start + width * 4]
        }

        return ScreenImage(width: width, height: height, pixels: pixels)
    }

    /// Resizes the image, averaging the source pixels under each output pixel so text stays legible when it
    /// shrinks.
    func scaled(width: Int, height: Int) -> ScreenImage {
        guard width != self.width || height != self.height else {
            return self
        }

        func span(_ index: Int, _ output: Int, _ input: Int) -> Range<Int> {
            let start = index * input / output
            return start..<max(start + 1, (index + 1) * input / output)
        }

        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for outputY in 0..<height {
            let rows = span(outputY, height, self.height)
            for outputX in 0..<width {
                let columns = span(outputX, width, self.width)
                var sums = (0, 0, 0, 0)
                for row in rows {
                    for column in columns {
                        let index = (row * self.width + column) * 4
                        sums.0 += Int(self.pixels[index])
                        sums.1 += Int(self.pixels[index + 1])
                        sums.2 += Int(self.pixels[index + 2])
                        sums.3 += Int(self.pixels[index + 3])
                    }
                }

                let count = rows.count * columns.count
                let index = (outputY * width + outputX) * 4
                pixels[index] = UInt8(sums.0 / count)
                pixels[index + 1] = UInt8(sums.1 / count)
                pixels[index + 2] = UInt8(sums.2 / count)
                pixels[index + 3] = UInt8(sums.3 / count)
            }
        }

        return ScreenImage(width: width, height: height, pixels: pixels)
    }

    /// An 8-bit RGBA PNG with no row filters.
    func png() throws -> Data {
        var rows = [UInt8]()
        rows.reserveCapacity(self.height * (self.width * 4 + 1))
        for row in 0..<self.height {
            rows.append(0)
            let start = row * self.width * 4
            rows += self.pixels[start..<start + self.width * 4]
        }

        var header = Data()
        header.appendBigEndian(UInt32(self.width))
        header.appendBigEndian(UInt32(self.height))
        header += [8, 6, 0, 0, 0]

        var png = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        png.appendChunk("IHDR", header)
        png.appendChunk("IDAT", try Self.deflate(rows))
        png.appendChunk("IEND", Data())
        return png
    }

    private static func deflate(_ bytes: [UInt8]) throws -> Data {
        var length = compressBound(uLong(bytes.count))
        var output = [UInt8](repeating: 0, count: Int(length))
        let status = compress2(&output, &length, bytes, uLong(bytes.count), Z_DEFAULT_COMPRESSION)
        guard status == Z_OK else {
            throw ScreenImageError.unreadable("zlib failed to compress the screenshot with status \(status)")
        }

        return Data(output[..<Int(length)])
    }
}

enum ScreenImageError: Error, CustomStringConvertible {
    case unreadable(String)

    var description: String {
        switch self {
        case .unreadable(let message):
            return message
        }
    }
}

private extension Data {
    mutating func appendBigEndian(_ value: UInt32) {
        Swift.withUnsafeBytes(of: value.bigEndian) { self += $0 }
    }

    mutating func appendChunk(_ type: String, _ body: Data) {
        let typed = Data(type.utf8) + body
        self.appendBigEndian(UInt32(body.count))
        self += typed
        let checksum = typed.withUnsafeBytes { buffer in
            crc32(0, buffer.bindMemory(to: Bytef.self).baseAddress, uInt(buffer.count))
        }
        self.appendBigEndian(UInt32(checksum))
    }
}
