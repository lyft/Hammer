#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Foundation
import HammerAgentCore

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

        let serial = try await AndroidDevice.resolveSerial(adb: self.adb, serial: self.serial)
        let screen = AndroidScreen(adb: self.adb, serial: serial)
        let arguments = JSONValue.object(arguments)
        switch descriptor.name {
        case AndroidSystemCommands.describe.name:
            let metrics = try await screen.metrics()
            return try DescribedElement.encode(try await screen.windows(scale: metrics.scale))
        case AndroidSystemCommands.tap.name:
            let metrics = try await screen.metrics()
            let target = try arguments.decode(as: ScreenTarget.self)
            let point = try await self.point(of: target, on: screen, metrics: metrics)
            try await screen.tap(point, metrics: metrics)
        case AndroidSystemCommands.swipe.name:
            let metrics = try await screen.metrics()
            let swipe = try arguments.decode(as: SwipeArguments.self)
            let center = try await self.point(of: swipe.target, on: screen, metrics: metrics)
            let line = swipe.line(centeredAt: center)
            try await screen.swipe(from: line.start, to: line.end, duration: swipe.duration ?? 0.2,
                                   metrics: metrics)
        case AndroidSystemCommands.edgeSwipe.name:
            let metrics = try await screen.metrics()
            let swipe = try arguments.decode(as: SwipeArguments.self)
            let line = swipe.edgeLine(in: metrics.bounds)
            try await screen.swipe(from: line.start, to: line.end, duration: swipe.duration ?? 0.2,
                                   metrics: metrics)
        case AndroidSystemCommands.typeText.name:
            try await self.type(try arguments.decode(as: TypingArguments.self), on: screen)
        case AndroidSystemCommands.pressKey.name:
            try await self.press(try arguments.decode(as: KeyArguments.self).key, on: screen)
        case AndroidSystemCommands.screenshot.name:
            return try await self.screenshot(try arguments.decode(as: ScreenshotArguments.self), of: screen)
        default:
            preconditionFailure("\(descriptor.name) is in AndroidSystemCommands.all but isn't run")
        }

        return Data("{}".utf8)
    }

    private func type(_ typing: TypingArguments, on screen: AndroidScreen) async throws {
        let hasTarget = try typing.target.query(traitNames: AndroidSystemCommands.traitNames) != nil
            || typing.target.point() != nil
        if hasTarget {
            let metrics = try await screen.metrics()
            let point = try await self.point(of: typing.target, on: screen, metrics: metrics)
            try await screen.tap(point, metrics: metrics)
            try await self.waitForFocusedTextField(at: point, on: screen, scale: metrics.scale)
        }

        try await screen.type(typing.text)
    }

    /// Waits until the text field at the tapped point has focus, so the text isn't typed before its keyboard
    /// shows, or into another field that had focus before the tap.
    private func waitForFocusedTextField(at point: CGPoint, on screen: AndroidScreen, scale: CGFloat)
        async throws
    {
        let deadline = ContinuousClock.now + Self.focusTimeout
        repeat {
            if Self.hasFocusedTextField(at: point, in: try await screen.windows(scale: scale)) {
                return
            }

            try await Task.sleep(for: .milliseconds(200))
        } while ContinuousClock.now < deadline

        throw ClientError.failed(.init(
            error: """
                The tapped field had no focus \(Self.focusTimeout.components.seconds) seconds after the tap
                """,
            code: .timedOut,
            hint: "Check the target is a text field with describe, or tap it and type without a target"))
    }

    private static let focusTimeout: Duration = .seconds(3)

    static func hasFocusedTextField(at point: CGPoint, in windows: [AndroidElement]) -> Bool {
        return windows.contains { window in
            window.flattened.contains { $0.isFocusedTextField && $0.frame.contains(point) }
        }
    }

    private func screenshot(_ capture: ScreenshotArguments, of screen: AndroidScreen) async throws -> Data {
        let metrics = try await screen.metrics()
        var area: CGRect?
        if let query = try capture.target.query(traitNames: AndroidSystemCommands.traitNames) {
            area = try query.element(in: Self.root(try await screen.windows(scale: metrics.scale))).frame
        }

        let image = try Self.png(try await screen.screenshot(), area: area, scale: capture.scale ?? 1,
                                 metrics: metrics)
        return try JSONEncoder().encode(AgentImage(mimeType: "image/png", data: image))
    }

    /// The target's point, or the center of the screen without one.
    private func point(of target: ScreenTarget, on screen: AndroidScreen, metrics: AndroidScreen.Metrics)
        async throws -> CGPoint
    {
        if let query = try target.query(traitNames: AndroidSystemCommands.traitNames) {
            let windows = try await screen.windows(scale: metrics.scale)
            let element = try query.element(in: Self.root(windows))
            return CGPoint(x: element.frame.midX, y: element.frame.midY)
        }

        return try target.point() ?? CGPoint(x: metrics.bounds.midX, y: metrics.bounds.midY)
    }

    private func press(_ key: String, on screen: AndroidScreen) async throws {
        if let code = AndroidSystemCommands.keyCodes[key] {
            try await screen.press(keyCode: code)
        } else if key.count == 1 {
            try await screen.type(key)
        } else {
            let names = Array(AndroidSystemCommands.keyCodes.keys).sorted()
            let suggestion = closestMatch(to: key, in: names).map { ", did you mean \($0)?" } ?? ""
            throw ClientError.invalidArguments("Unknown key \"\(key)\"\(suggestion)", hint: """
                Pass a single character or a key name, such as deviceBack, deviceHome, appSwitch, \
                returnOrEnter, escape, deleteOrBackspace, tab, arrowUp or arrowDown
                """)
        }
    }

    /// The windows under one root, so queries search all of them.
    private static func root(_ windows: [AndroidElement]) -> AndroidElement {
        return AndroidElement(type: "Screen", identifier: nil, label: nil, value: nil, traits: [],
                              frame: .zero, children: windows)
    }

    /// Crops the screenshot to the area in dp and scales it to the pixels per dp.
    static func png(_ data: Data, area: CGRect?, scale: Double, metrics: AndroidScreen.Metrics) throws
        -> Data
    {
        guard scale > 0 && scale <= 4 else {
            throw ClientError.invalidArguments("Invalid scale \(scale)",
                                               hint: "Pass a scale above 0 and up to 4")
        }

        let image: ScreenImage
        do {
            image = try ScreenImage(screencap: data)
        } catch {
            throw ClientError.failed(.init(error: String(describing: error), code: .failed,
                                           hint: "Check `adb exec-out screencap` works on the device"))
        }

        let screen = metrics.bounds
        let crop = (area ?? screen).intersection(screen)
        guard !crop.isEmpty else {
            throw ClientError.invalidArguments("The element's frame is empty or off screen",
                                               hint: "Call describe to check its frame")
        }

        let left = max(0, Int((crop.minX * metrics.scale).rounded(.down)))
        let top = max(0, Int((crop.minY * metrics.scale).rounded(.down)))
        let right = min(image.width, Int((crop.maxX * metrics.scale).rounded(.up)))
        let bottom = min(image.height, Int((crop.maxY * metrics.scale).rounded(.up)))
        guard right > left, bottom > top else {
            throw ClientError.invalidArguments("The element's frame is empty or off screen",
                                               hint: "Call describe to check its frame")
        }

        let width = max(1, Int((crop.width * scale).rounded()))
        let height = max(1, Int((crop.height * scale).rounded()))
        do {
            return try image.cropped(x: left, y: top, width: right - left, height: bottom - top)
                .scaled(width: width, height: height)
                .png()
        } catch {
            throw ClientError.failed(.init(error: String(describing: error), code: .failed))
        }
    }
}

struct SwipeArguments: Decodable {
    private enum CodingKeys: String, CodingKey {
        case direction
        case distance
        case duration
    }

    enum Direction: String, Decodable {
        case up
        case down
        case left
        case right
    }

    let target: ScreenTarget
    let direction: Direction
    let distance: Double?
    let duration: Double?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.target = try ScreenTarget(from: decoder)
        self.direction = try container.decode(Direction.self, forKey: .direction)
        self.distance = try container.decodeIfPresent(Double.self, forKey: .distance)
        self.duration = try container.decodeIfPresent(Double.self, forKey: .duration)
    }

    private var vector: (dx: Double, dy: Double) {
        switch self.direction {
        case .up: return (0, -1)
        case .down: return (0, 1)
        case .left: return (-1, 0)
        case .right: return (1, 0)
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
