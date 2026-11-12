#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Foundation
@testable import HammerCLI
import HammerAgentCore
#if canImport(ImageIO)
import ImageIO
#endif
import Testing

/// A raw `screencap` capture: the width, height and format as little endian integers, an optional color
/// space, then RGBA pixels.
private func screencap(width: Int, height: Int, pixels: [UInt8], colorSpace: Bool = true) -> Data {
    var data = Data()
    for field in [width, height, 1] + (colorSpace ? [1] : []) {
        data += withUnsafeBytes(of: UInt32(field).littleEndian, Array.init)
    }
    return data + pixels
}

/// The pixel at (x, y), as RGBA.
private func pixel(_ image: ScreenImage, _ x: Int, _ y: Int) -> [UInt8] {
    let index = (y * image.width + x) * 4
    return Array(image.pixels[index..<index + 4])
}

/// A 4x2 image whose pixel at (x, y) is (10x, 10y, 0, 255).
private let gradient = ScreenImage(width: 4, height: 2, pixels: (0..<2).flatMap { y in
    (0..<4).flatMap { x in [UInt8(10 * x), UInt8(10 * y), 0, 255] }
})

struct ScreenImageTests {
    @Test(arguments: [true, false])
    func readsTheCaptureWithOrWithoutAColorSpace(colorSpace: Bool) throws {
        let image = try ScreenImage(screencap: screencap(width: 4, height: 2, pixels: gradient.pixels,
                                                         colorSpace: colorSpace))

        #expect(image == gradient)
    }

    @Test
    func rejectsACaptureWhosePixelsDontMatchItsSize() {
        let data = screencap(width: 4, height: 2, pixels: Array(gradient.pixels.dropLast(1)))

        #expect(throws: ScreenImageError.self) {
            try ScreenImage(screencap: data)
        }
    }

    @Test
    func rejectsAFormatOtherThanRGBA8888() {
        var data = screencap(width: 4, height: 2, pixels: gradient.pixels)
        data[8] = 2

        #expect(throws: ScreenImageError.self) {
            try ScreenImage(screencap: data)
        }
    }

    @Test
    func cropKeepsThePixelsInsideTheRectangle() {
        let cropped = gradient.cropped(x: 1, y: 1, width: 2, height: 1)

        #expect(cropped == ScreenImage(width: 2, height: 1, pixels: [10, 10, 0, 255, 20, 10, 0, 255]))
    }

    @Test
    func shrinkingAveragesThePixelsUnderEachOutputPixel() {
        let scaled = gradient.scaled(width: 2, height: 1)

        #expect(scaled == ScreenImage(width: 2, height: 1, pixels: [5, 5, 0, 255, 25, 5, 0, 255]))
    }

    @Test
    func growingRepeatsEachPixel() {
        let scaled = ScreenImage(width: 1, height: 1, pixels: [1, 2, 3, 4]).scaled(width: 2, height: 2)

        #expect(scaled.pixels == Array([[UInt8]](repeating: [1, 2, 3, 4], count: 4).joined()))
    }

    @Test
    func pngStartsWithTheSignatureAndTheImagesSize() throws {
        let png = try gradient.png()

        #expect(Array(png.prefix(8)) == [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        #expect(Array(png[12..<16]) == Array("IHDR".utf8))
        #expect(Array(png[16..<24]) == [0, 0, 0, 4, 0, 0, 0, 2])
    }

    #if canImport(ImageIO)
    @Test
    func pngDecodesToTheSamePixels() throws {
        let png = try gradient.png()
        let source = try #require(CGImageSourceCreateWithData(png as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        var decoded = [UInt8](repeating: 0, count: 4 * 2 * 4)
        let context = try #require(CGContext(data: &decoded, width: 4, height: 2, bitsPerComponent: 8,
                                             bytesPerRow: 16, space: CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: 4, height: 2))

        #expect(decoded == gradient.pixels)
    }
    #endif
}

struct SystemScreenshotTests {
    /// A 4x2 pixel screen at 2 pixels per dp, so 2x1 dp.
    private let metrics = AndroidScreen.Metrics(size: CGSize(width: 4, height: 2), scale: 2)

    private func size(_ png: Data) -> [Int] {
        let size = [UInt8](png[16..<24])
        func integer(_ bytes: ArraySlice<UInt8>) -> Int { bytes.reduce(0) { $0 << 8 | Int($1) } }
        return [integer(size[0..<4]), integer(size[4..<8])]
    }

    @Test
    func wholeScreenIsScaledToTheGivenPixelsPerDp() throws {
        let data = screencap(width: 4, height: 2, pixels: gradient.pixels)

        let png = try AndroidSystemDriver.png(data, area: nil, scale: 1, metrics: self.metrics)

        #expect(self.size(png) == [2, 1])
    }

    @Test
    func elementAreaIsCroppedInDp() throws {
        let data = screencap(width: 4, height: 2, pixels: gradient.pixels)

        let png = try AndroidSystemDriver.png(data, area: CGRect(x: 1, y: 0, width: 1, height: 1), scale: 2,
                                              metrics: self.metrics)

        #expect(self.size(png) == [2, 2])
    }

    @Test
    func areaOffScreenIsRejected() {
        let data = screencap(width: 4, height: 2, pixels: gradient.pixels)

        #expect(throws: ClientError.self) {
            try AndroidSystemDriver.png(data, area: CGRect(x: 5, y: 5, width: 1, height: 1), scale: 1,
                                        metrics: self.metrics)
        }
    }

    @Test
    func unreadableCaptureFails() {
        #expect(throws: ClientError.self) {
            try AndroidSystemDriver.png(Data([1, 2, 3]), area: nil, scale: 1, metrics: self.metrics)
        }
    }
}
