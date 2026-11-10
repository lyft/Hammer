import CoreGraphics
import Foundation
import HammerAgentCore
import ImageIO
import UniformTypeIdentifiers

/// Runs commands on an Android device's whole screen through adb, like a person holding the device, so they
/// reach system UI the app's agent can't, such as permission dialogs and the notification shade.
struct AndroidSystemDriver: Driver {
    let adb: Adb

    /// The device to drive, or nil for `ANDROID_SERIAL` or the only attached one.
    let serial: String?

    func catalog() async -> DriverCatalog {
        return DriverCatalog(commands: AndroidSystemCommands.all, note: nil)
    }

    func callableCommands() async throws -> [CommandDescriptor] {
        return AndroidSystemCommands.all
    }

    func run(_ name: String, arguments: [String: JSONValue]) async throws -> Data {
        guard let descriptor = AndroidSystemCommands.all.first(where: { $0.name == name }) else {
            let names = AndroidSystemCommands.all.map(\.name).joined(separator: ", ")
            throw ClientError.failed(.init(error: "\(name) does not run on the device's screen",
                                           code: .unknownCommand,
                                           hint: "Only \(names) do. Run \(name) in the app instead"),
                                     isInvalidCall: true)
        }

        do {
            try descriptor.validate(arguments)
        } catch let error as ArgumentsError {
            throw ClientError.invalidArguments(error.description, hint: error.hint)
        }

        let serial = try AndroidDevice.resolveSerial(adb: self.adb, serial: self.serial)
        let screen = AndroidScreen(adb: self.adb, serial: serial)
        let metrics = try screen.metrics()
        let arguments = JSONValue.object(arguments)
        switch descriptor.name {
        case AndroidSystemCommands.describe.name:
            return try DescribedElement.encode(try await screen.windows(metrics: metrics))
        case AndroidSystemCommands.tap.name:
            try await self.tap(try arguments.decode(as: CountedTarget.self), on: screen, metrics: metrics)
        case AndroidSystemCommands.swipe.name, AndroidSystemCommands.edgeSwipe.name:
            let swipe = try arguments.decode(as: SwipeArguments.self)
            let line = descriptor.name == AndroidSystemCommands.swipe.name
                ? swipe.line(centeredAt: try await self.point(of: swipe.target, on: screen, metrics: metrics))
                : swipe.edgeLine(in: metrics.bounds)
            try screen.swipe(from: line.start, to: line.end, duration: swipe.duration ?? 0.2,
                             metrics: metrics)
        case AndroidSystemCommands.typeText.name:
            try await self.type(try arguments.decode(as: TypingArguments.self), on: screen, metrics: metrics)
        case AndroidSystemCommands.pressKey.name:
            try self.press(try arguments.decode(as: KeyArguments.self).key, on: screen)
        default:
            return try await self.screenshot(try arguments.decode(as: ScreenshotArguments.self), of: screen,
                                             metrics: metrics)
        }

        return Data("{}".utf8)
    }

    private func tap(_ tap: CountedTarget, on screen: AndroidScreen, metrics: AndroidScreen.Metrics)
        async throws
    {
        guard tap.count ?? 1 > 0 else {
            throw ClientError.invalidArguments("Invalid count \(tap.count ?? 0), expected 1 or more",
                                               hint: "Use 1 for a tap and 2 for a double tap")
        }

        let point = try await self.point(of: tap.target, on: screen, metrics: metrics)
        try screen.tap(point, count: tap.count ?? 1, metrics: metrics)
    }

    private func type(_ typing: TypingArguments, on screen: AndroidScreen, metrics: AndroidScreen.Metrics)
        async throws
    {
        let hasTarget = try typing.target.query(traitNames: AndroidSystemCommands.traitNames) != nil
            || typing.target.point() != nil
        if hasTarget {
            let point = try await self.point(of: typing.target, on: screen, metrics: metrics)
            try screen.tap(point, count: 1, metrics: metrics)
            // The field focuses and shows its keyboard after the tap
            try await Task.sleep(for: .milliseconds(500))
        }

        try screen.type(typing.text)
    }

    private func screenshot(_ capture: ScreenshotArguments, of screen: AndroidScreen,
                            metrics: AndroidScreen.Metrics) async throws -> Data
    {
        var area: CGRect?
        if let query = try capture.target.query(traitNames: AndroidSystemCommands.traitNames) {
            area = try query.element(in: Self.root(try await screen.windows(metrics: metrics))).frame
        }

        let image = try Self.png(try screen.screenshot(), area: area, scale: capture.scale ?? 1,
                                 metrics: metrics)
        return try JSONEncoder().encode(AgentImage(mimeType: "image/png", data: image))
    }

    /// The target's point, or the center of the screen without one.
    private func point(of target: ScreenTarget, on screen: AndroidScreen, metrics: AndroidScreen.Metrics)
        async throws -> CGPoint
    {
        if let query = try target.query(traitNames: AndroidSystemCommands.traitNames) {
            let element = try query.element(in: Self.root(try await screen.windows(metrics: metrics)))
            return CGPoint(x: element.frame.midX, y: element.frame.midY)
        }

        return try target.point() ?? CGPoint(x: metrics.bounds.midX, y: metrics.bounds.midY)
    }

    private func press(_ key: String, on screen: AndroidScreen) throws {
        if let code = AndroidSystemCommands.keyCodes[key] {
            try screen.press(keyCode: code)
        } else if key.count == 1 {
            try screen.type(key)
        } else {
            let names = Array(AndroidSystemCommands.keyCodes.keys).sorted()
            let suggestion = closestMatch(to: key, in: names).map { ", did you mean \($0)?" } ?? ""
            throw ClientError.invalidArguments("Unknown key \"\(key)\"\(suggestion)", hint: """
                Pass a single character or a key name, such as back, home, appSwitch, returnOrEnter, escape, \
                deleteOrBackspace, tab, arrowUp or arrowDown
                """)
        }
    }

    /// The windows under one root, so queries search all of them.
    private static func root(_ windows: [AndroidElement]) -> AndroidElement {
        return AndroidElement(type: "Screen", identifier: nil, label: nil, value: nil, traits: [],
                              frame: .zero, children: windows)
    }

    /// Crops the screenshot to the area in dp and scales it to the pixels per dp.
    private static func png(_ data: Data, area: CGRect?, scale: Double,
                            metrics: AndroidScreen.Metrics) throws -> Data
    {
        guard scale > 0 && scale <= 4 else {
            throw ClientError.invalidArguments("Invalid scale \(scale)",
                                               hint: "Pass a scale above 0 and up to 4")
        }

        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw ClientError.failed(.init(error: "screencap returned no image", code: .failed,
                                           hint: "Check `adb exec-out screencap -p` works on the device"))
        }

        let screen = metrics.bounds
        let crop = (area ?? screen).intersection(screen)
        guard !crop.isEmpty, let cropped = image.cropping(to: crop.applying(
            CGAffineTransform(scaleX: metrics.scale, y: metrics.scale)).integral)
        else {
            throw ClientError.invalidArguments("The element's frame is empty or off screen",
                                               hint: "Call describe to check its frame")
        }

        let width = max(1, Int((crop.width * scale).rounded()))
        let height = max(1, Int((crop.height * scale).rounded()))
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else {
            throw ClientError.failed(.init(error: "Unable to scale the screenshot", code: .failed))
        }

        context.interpolationQuality = .high
        context.draw(cropped, in: CGRect(x: 0, y: 0, width: width, height: height))
        let output = NSMutableData()
        guard let scaled = context.makeImage(),
              let destination = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString,
                                                                 1, nil)
        else {
            throw ClientError.failed(.init(error: "Unable to encode the screenshot", code: .failed))
        }

        CGImageDestinationAddImage(destination, scaled, nil)
        CGImageDestinationFinalize(destination)
        return output as Data
    }
}

private struct CountedTarget: Decodable {
    private enum CodingKeys: String, CodingKey {
        case count
    }

    let target: ScreenTarget
    let count: Int?

    init(from decoder: Decoder) throws {
        self.target = try ScreenTarget(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.count = try container.decodeIfPresent(Int.self, forKey: .count)
    }
}

private struct SwipeArguments: Decodable {
    private enum CodingKeys: String, CodingKey {
        case direction
        case distance
        case duration
    }

    let target: ScreenTarget
    let direction: String
    let distance: Double?
    let duration: Double?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.target = try ScreenTarget(from: decoder)
        self.direction = try container.decode(String.self, forKey: .direction)
        self.distance = try container.decodeIfPresent(Double.self, forKey: .distance)
        self.duration = try container.decodeIfPresent(Double.self, forKey: .duration)
    }

    private var vector: CGVector {
        switch self.direction {
        case "up": return CGVector(dx: 0, dy: -1)
        case "down": return CGVector(dx: 0, dy: 1)
        case "left": return CGVector(dx: -1, dy: 0)
        default: return CGVector(dx: 1, dy: 0)
        }
    }

    /// The line the finger moves along, centered on the point as Hammer's swipes are.
    func line(centeredAt center: CGPoint) -> (start: CGPoint, end: CGPoint) {
        let half = (self.distance ?? 200) / 2
        return (CGPoint(x: center.x - self.vector.dx * half, y: center.y - self.vector.dy * half),
                CGPoint(x: center.x + self.vector.dx * half, y: center.y + self.vector.dy * half))
    }

    /// The line from the edge opposite the direction, starting just inside the screen so the touch lands.
    func edgeLine(in screen: CGRect) -> (start: CGPoint, end: CGPoint) {
        let inner = screen.insetBy(dx: 1, dy: 1)
        let start = CGPoint(x: inner.midX - self.vector.dx * inner.width / 2,
                            y: inner.midY - self.vector.dy * inner.height / 2)
        let distance = self.distance ?? 200
        let end = CGPoint(x: start.x + self.vector.dx * distance, y: start.y + self.vector.dy * distance)
        return (start, end)
    }
}

private struct TypingArguments: Decodable {
    private enum CodingKeys: String, CodingKey {
        case text
    }

    let target: ScreenTarget
    let text: String

    init(from decoder: Decoder) throws {
        self.target = try ScreenTarget(from: decoder)
        self.text = try decoder.container(keyedBy: CodingKeys.self).decode(String.self, forKey: .text)
    }
}

private struct KeyArguments: Decodable {
    let key: String
}

private struct ScreenshotArguments: Decodable {
    private enum CodingKeys: String, CodingKey {
        case scale
    }

    let target: ScreenTarget
    let scale: Double?

    init(from decoder: Decoder) throws {
        self.target = try ScreenTarget(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.scale = try container.decodeIfPresent(Double.self, forKey: .scale)
    }
}
