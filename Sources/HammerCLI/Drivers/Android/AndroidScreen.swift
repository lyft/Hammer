import CoreGraphics
import Foundation
import HammerAgentCore

/// An accessibility node on an Android device's screen, from `uiautomator dump`.
struct AndroidElement: ScreenElement {
    let type: String
    let identifier: String?
    let label: String?
    let value: String?
    let traits: [String]
    let frame: CGRect
    let children: [AndroidElement]
}

/// Reads and drives an Android device's whole screen through adb's shell user, which can inject input
/// anywhere, unlike an app.
struct AndroidScreen: Sendable {
    let adb: Adb
    let serial: String

    /// The screen's size in pixels and its pixels per dp.
    struct Metrics {
        let size: CGSize
        let scale: CGFloat

        var bounds: CGRect {
            return CGRect(x: 0, y: 0, width: self.size.width / self.scale,
                          height: self.size.height / self.scale)
        }

        /// A point in dp as the pixel `input` takes.
        func pixel(_ point: CGPoint) -> (x: Int, y: Int) {
            return (Int((point.x * self.scale).rounded()), Int((point.y * self.scale).rounded()))
        }
    }

    func metrics() throws -> Metrics {
        let output = try self.shell("wm size; wm density")
        return try Self.metrics(from: output)
    }

    /// The windows on screen back to front, each with its accessibility nodes.
    ///
    /// - throws: A `timed_out` error if the screen kept changing, so uiautomator could not read it.
    func windows(metrics: Metrics) async throws -> [AndroidElement] {
        // --windows lists every window on screen, such as the status bar, on recent versions only
        var arguments = "--windows /dev/tty"
        var lastError = ""
        var idleTimeouts = 0
        while idleTimeouts < Self.idleAttempts {
            let command = ["-s", self.serial, "exec-out", "uiautomator dump \(arguments)"]
            let output = (try? self.adb.run(command)) ?? ""
            if let windows = UIAutomatorDump.parse(output, scale: metrics.scale), !windows.isEmpty {
                return windows
            }

            lastError = output.trimmingCharacters(in: .whitespacesAndNewlines)
            if lastError.contains("idle state") {
                // uiautomator waits up to 10 seconds for accessibility events to stop before giving up
                idleTimeouts += 1
            } else if arguments != "/dev/tty" {
                arguments = "/dev/tty"
            } else {
                break
            }
        }

        throw ClientError.failed(.init(
            error: "uiautomator could not read the screen: \(lastError.prefix(200))", code: .timedOut,
            hint: "The screen keeps changing, such as during an animation or video. Wait and try again"))
    }

    func tap(_ point: CGPoint, count: Int, metrics: Metrics) throws {
        let (x, y) = metrics.pixel(point)
        try self.shell(Array(repeating: "input tap \(x) \(y)", count: count).joined(separator: "; "))
    }

    func swipe(from start: CGPoint, to end: CGPoint, duration: TimeInterval, metrics: Metrics) throws {
        let (x1, y1) = metrics.pixel(start)
        let (x2, y2) = metrics.pixel(end)
        try self.shell("input swipe \(x1) \(y1) \(x2) \(y2) \(Int(duration * 1000))")
    }

    /// Types ASCII text into the focused field.
    func type(_ text: String) throws {
        guard text.unicodeScalars.allSatisfy({ $0.isASCII && $0.value >= 0x20 }) else {
            throw ClientError.invalidArguments("Only printable ASCII characters can be typed from adb",
                                               hint: "Type other text inside the app, without system")
        }

        // input text reads %s as a space
        try self.shell("input text \(Self.quoted(text.replacingOccurrences(of: " ", with: "%s")))")
    }

    func press(keyCode: String) throws {
        try self.shell("input keyevent \(keyCode)")
    }

    /// The screen as PNG data, with the surfaces of maps and videos that the app's agent can't capture.
    func screenshot() throws -> Data {
        return try self.adb.runData(["-s", self.serial, "exec-out", "screencap -p"])
    }

    @discardableResult
    private func shell(_ command: String) throws -> String {
        return try self.adb.run(["-s", self.serial, "shell", command])
    }

    private static let idleAttempts = 2

    static func metrics(from output: String) throws -> Metrics {
        func last(_ pattern: Regex<(Substring, Substring)>) -> Substring? {
            // An override, listed after the physical value, is what apps and input use
            return output.matches(of: pattern).last?.1
        }

        let size = last(#/size: (\d+x\d+)/#)?.split(separator: "x").compactMap { Double($0) }
        guard let size, size.count == 2, let density = last(#/density: (\d+)/#).flatMap({ Double($0) }) else {
            throw ClientError.noDevice("Unable to read the screen size from \"\(output)\"",
                                       hint: "Check `adb shell wm size` and `adb shell wm density` work")
        }

        return Metrics(size: CGSize(width: size[0], height: size[1]), scale: density / 160)
    }

    static func quoted(_ string: String) -> String {
        return "'" + string.replacingOccurrences(of: "'", with: #"'\''"#) + "'"
    }
}

/// Parses `uiautomator dump`'s XML into elements with frames in dp.
final class UIAutomatorDump: NSObject, XMLParserDelegate {
    private struct Node {
        var element: AndroidElement
        var children: [AndroidElement] = []
        var layer: Int = 0
        var isWindow = false

        /// The app or system component that owns a window, from its first node.
        var package: String?
    }

    private let scale: CGFloat
    private var stack: [Node] = []
    private var roots: [(element: AndroidElement, layer: Int)] = []

    private init(scale: CGFloat) {
        self.scale = scale
    }

    /// The windows back to front, or the one root of a dump without windows, or nil if the output is no dump.
    static func parse(_ output: String, scale: CGFloat) -> [AndroidElement]? {
        // The dump is followed by "UI hierchary dumped to: /dev/tty"
        let end = output.range(of: "UI hierchary dumped")?.lowerBound ?? output.endIndex
        guard let start = output.range(of: "<?xml"), start.lowerBound < end else {
            return nil
        }

        let dump = UIAutomatorDump(scale: scale)
        let parser = XMLParser(data: Data(output[start.lowerBound..<end].utf8))
        parser.delegate = dump
        guard parser.parse() else {
            return nil
        }

        return dump.roots.enumerated()
            .sorted { ($0.element.layer, $0.offset) < ($1.element.layer, $1.offset) }
            .map(\.element.element)
    }

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
                qualifiedName: String?, attributes: [String: String])
    {
        switch name {
        case "window":
            let element = AndroidElement(type: "Window", identifier: nil, label: attributes["title"].nonEmpty,
                                         value: nil, traits: [], frame: self.frame(attributes["bounds"]),
                                         children: [])
            self.stack.append(Node(element: element, layer: Int(attributes["layer"] ?? "") ?? 0,
                                   isWindow: true))
        case "node":
            if let window = self.stack.indices.last, self.stack[window].isWindow,
               self.stack[window].package == nil
            {
                self.stack[window].package = attributes["package"].nonEmpty
            }

            self.stack.append(Node(element: self.element(attributes)))
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?,
                qualifiedName: String?)
    {
        guard name == "window" || name == "node", let node = self.stack.popLast() else {
            return
        }

        // A window shows in describe by its title, or the package that owns it, such as com.android.systemui
        let label = node.isWindow ? node.element.label ?? node.package : node.element.label
        let element = AndroidElement(type: node.element.type, identifier: node.element.identifier,
                                     label: label, value: node.element.value,
                                     traits: node.element.traits, frame: node.element.frame,
                                     children: node.children)
        if self.stack.isEmpty {
            self.roots.append((element, node.layer))
        } else {
            self.stack[self.stack.count - 1].children.append(element)
        }
    }

    private func element(_ attributes: [String: String]) -> AndroidElement {
        let className = attributes["class"] ?? ""
        let isEditable = className.hasSuffix("EditText")
        let text = attributes["text"].nonEmpty
        let description = attributes["content-desc"].nonEmpty
        let resourceID = attributes["resource-id"].nonEmpty
        func flag(_ name: String) -> Bool { attributes[name] == "true" }

        var traits: [String] = []
        if flag("clickable") || flag("long-clickable") || className.hasSuffix("Button") {
            traits.append("button")
        } else if className.hasSuffix("ImageView") {
            traits.append("image")
        } else if className.hasSuffix("TextView") {
            traits.append("staticText")
        }
        if flag("checkable") {
            traits.append("toggleButton")
        }
        if flag("checked") || flag("selected") {
            traits.append("selected")
        }
        if attributes["enabled"] == "false" {
            traits.append("notEnabled")
        }

        return AndroidElement(
            type: className.split(separator: ".").last.map(String.init) ?? className,
            identifier: resourceID.map { $0.components(separatedBy: ":id/").last ?? $0 },
            label: description ?? (isEditable ? attributes["hint"].nonEmpty : text),
            value: isEditable ? text : nil, traits: traits, frame: self.frame(attributes["bounds"]),
            children: [])
    }

    /// The frame in dp of bounds such as `[0,0][1344,2992]`, in pixels.
    private func frame(_ bounds: String?) -> CGRect {
        let numbers = (bounds ?? "").matches(of: #/-?\d+/#).compactMap { Double($0.output) }
        guard numbers.count == 4 else {
            return .zero
        }

        return CGRect(x: numbers[0], y: numbers[1], width: numbers[2] - numbers[0],
                      height: numbers[3] - numbers[1])
            .applying(CGAffineTransform(scaleX: 1 / self.scale, y: 1 / self.scale))
    }
}

extension Optional where Wrapped == String {
    fileprivate var nonEmpty: String? {
        return self?.isEmpty == false ? self : nil
    }
}
