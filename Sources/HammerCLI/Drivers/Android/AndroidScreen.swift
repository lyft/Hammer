#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif
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

    /// Whether the node is a text field with input focus, which `type_text` types into.
    var isFocusedTextField = false
}

/// Reads and drives an Android device's whole screen through adb's shell user, which can inject input
/// anywhere, unlike an app.
struct AndroidScreen: Sendable {
    let adb: Adb
    let serial: String

    /// The screen's size in pixels as it is rotated now, and its pixels per dp.
    struct Metrics: Equatable {
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

    // `wm size` is the size in the natural orientation, while input, screencap and uiautomator use the
    // display's current size, which `cur=` lists
    static let metricsCommand =
        "wm density; wm size; dumpsys window displays | grep -o 'cur=[0-9]*x[0-9]*' || true"

    func metrics() async throws -> Metrics {
        return try Self.metrics(from: try await self.shell(Self.metricsCommand))
    }

    /// The windows on screen back to front, each with its accessibility nodes.
    ///
    /// - throws: A `timed_out` error if the screen kept changing so uiautomator could not read it, or a
    ///           `failed` error with uiautomator's.
    func windows(scale: CGFloat) async throws -> [AndroidElement] {
        // --windows lists every window on screen, such as the status bar. Versions without it get one dump
        // of the active window
        var options = "--windows"
        var lastError = ""
        for _ in 0..<Self.dumpAttempts {
            let output: String
            do {
                output = try await self.shell(Self.dumpCommand(options: options))
            } catch ClientError.failed(let body, _) where body.code == .failed {
                lastError = body.error
                if Self.isTransientDumpError(lastError) {
                    continue
                } else if !options.isEmpty {
                    options = ""
                    continue
                }
                throw ClientError.failed(.init(error: "uiautomator could not read the screen: \(lastError)",
                                               code: .failed))
            }

            guard let windows = UIAutomatorDump.parse(output, scale: scale) else {
                throw ClientError.failed(.init(
                    error: "uiautomator returned no hierarchy: \(output.prefix(200))", code: .failed))
            }

            return windows
        }

        throw ClientError.failed(.init(
            error: "uiautomator could not read the screen: \(lastError)", code: .timedOut,
            hint: "The screen keeps changing, such as during an animation or video. Wait and try again"))
    }

    func tap(_ point: CGPoint, metrics: Metrics) async throws {
        let (x, y) = metrics.pixel(point)
        try await self.shell("input tap \(x) \(y)")
    }

    func swipe(from start: CGPoint, to end: CGPoint, duration: TimeInterval, metrics: Metrics) async throws {
        let (x1, y1) = metrics.pixel(start)
        let (x2, y2) = metrics.pixel(end)
        try await self.shell("input swipe \(x1) \(y1) \(x2) \(y2) \(Int(duration * 1000))")
    }

    /// Types ASCII text into the focused field.
    func type(_ text: String) async throws {
        guard text.unicodeScalars.allSatisfy({ $0.isASCII && $0.value >= 0x20 && $0.value < 0x7F }) else {
            throw ClientError.invalidArguments("Only printable ASCII characters can be typed from adb",
                                               hint: "Type other text inside the app, without system")
        }

        try await self.shell(Self.typingCommand(text))
    }

    func press(keyCode: String) async throws {
        try await self.shell("input keyevent \(keyCode)")
    }

    /// The screen's raw pixels, with the surfaces of maps and videos that the app's agent can't capture.
    /// Encoding a PNG on the device takes about a second, longer than sending the pixels.
    func screenshot() async throws -> Data {
        return try await self.adb.runData(["-s", self.serial, "exec-out", "screencap"])
    }

    @discardableResult
    private func shell(_ command: String) async throws -> String {
        return try await self.adb.run(["-s", self.serial, "shell", command])
    }

    private static let dumpAttempts = 3

    /// Dumps to a file and prints it, since not every device has a `/dev/tty` to dump to. A failed dump
    /// leaves no file, so `cat` fails with uiautomator's error, which can exit 0.
    static func dumpCommand(options: String) -> String {
        let file = "/data/local/tmp/hammer-\(UUID().uuidString).xml"
        let dump = ["uiautomator", "dump", options, file].filter { !$0.isEmpty }.joined(separator: " ")
        return "\(dump) 1>&2; cat \(file); status=$?; rm -f \(file); exit $status"
    }

    /// Whether uiautomator failed because the screen was changing, so a retry can succeed.
    static func isTransientDumpError(_ error: String) -> Bool {
        // uiautomator waits up to 10 seconds for accessibility events to stop, and has no root node while
        // an activity starts
        return error.contains("idle state") || error.contains("null root node")
    }

    /// The `input text` commands that type the text.
    ///
    /// `input text` reads `%s` as a space, so spaces are sent as `%s`, and a `%` followed by an `s` in the
    /// text ends one command so the next types the `s`.
    static func typingCommand(_ text: String) -> String {
        let parts = text.components(separatedBy: "%s")
        return parts.enumerated()
            .map { index, part in
                (index == 0 ? "" : "s") + part + (index == parts.count - 1 ? "" : "%")
            }
            .filter { !$0.isEmpty }
            .map { "input text \(self.quoted($0.replacingOccurrences(of: " ", with: "%s")))" }
            .joined(separator: " && ")
    }

    static func metrics(from output: String) throws -> Metrics {
        let current = output.firstMatch(of: #/cur=(\d+)x(\d+)/#).map { (String($0.1), String($0.2)) }
        // An override, listed after the physical value, is what apps and input use
        let natural = output.matches(of: #/size: (\d+)x(\d+)/#).last.map { (String($0.1), String($0.2)) }
        guard let (width, height) = current ?? natural,
              let width = Double(width), let height = Double(height),
              let density = output.matches(of: #/density: (\d+)/#).last.flatMap({ Double($0.1) })
        else {
            throw ClientError.failed(.init(
                error: "Unable to read the screen size from \"\(output.prefix(200))\"", code: .failed,
                hint: "Check `adb shell wm size` and `adb shell wm density` work"))
        }

        return Metrics(size: CGSize(width: width, height: height), scale: density / 160)
    }

    static func quoted(_ string: String) -> String {
        return "'" + string.replacingOccurrences(of: "'", with: #"'\''"#) + "'"
    }
}

/// Parses `uiautomator dump`'s XML into elements with frames in dp, with the traits and values the app's
/// agent gives Views.
final class UIAutomatorDump: NSObject, XMLParserDelegate {
    private struct Node {
        var element: AndroidElement
        var children: [AndroidElement] = []
        var layer: Int = 0
        var isWindow = false

        /// The app or system component that owns a window, from its first node.
        var package: String?
    }

    static let textFieldClassSuffixes = ["EditText", "AutoCompleteTextView", "SearchAutoComplete"]

    private let scale: CGFloat
    private var stack: [Node] = []
    private var roots: [(element: AndroidElement, layer: Int)] = []

    private init(scale: CGFloat) {
        self.scale = scale
    }

    /// The windows back to front, or the one root of a dump without windows, or nil if the output is no dump.
    static func parse(_ output: String, scale: CGFloat) -> [AndroidElement]? {
        guard let start = output.range(of: "<?xml") else {
            return nil
        }

        let dump = UIAutomatorDump(scale: scale)
        let parser = XMLParser(data: Data(output[start.lowerBound...].utf8))
        parser.delegate = dump
        guard parser.parse(), !dump.roots.isEmpty else {
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
            // displays, display and hierarchy only group windows and nodes
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
                                     children: node.children,
                                     isFocusedTextField: node.element.isFocusedTextField)
        if self.stack.isEmpty {
            self.roots.append((element, node.layer))
        } else {
            self.stack[self.stack.count - 1].children.append(element)
        }
    }

    private func element(_ attributes: [String: String]) -> AndroidElement {
        let className = attributes["class"] ?? ""
        // Views report their accessibility class name, which is EditText for its subclasses, such as
        // AutoCompleteTextView and SearchView's field, unless one reports its own
        let isEditable = Self.textFieldClassSuffixes.contains { className.hasSuffix($0) }
        let text = attributes["text"].nonEmpty
        let description = attributes["content-desc"].nonEmpty
        let resourceID = attributes["resource-id"].nonEmpty
        func flag(_ name: String) -> Bool { attributes[name] == "true" }

        var traits: [String] = []
        if flag("checkable") {
            traits.append("toggleButton")
        } else if flag("clickable") {
            traits.append("button")
        } else if className.hasSuffix("ImageView") && description != nil {
            traits.append("image")
        } else if className.hasSuffix("TextView") && text != nil {
            traits.append("staticText")
        }
        if flag("selected") || flag("checked") {
            traits.append("selected")
        }
        if attributes["enabled"] == "false" {
            traits.append("notEnabled")
        }

        // An empty field reports its hint as its text
        let hint = attributes["hint"].nonEmpty
        let value: String? = isEditable ? (text == hint ? nil : text)
            : flag("checkable") ? (flag("checked") ? "1" : "0") : nil
        return AndroidElement(
            type: className.split(separator: ".").last.map(String.init) ?? className,
            identifier: resourceID.map { $0.components(separatedBy: ":id/").last ?? $0 },
            label: description ?? (isEditable ? hint : text),
            value: value, traits: traits, frame: self.frame(attributes["bounds"]), children: [],
            isFocusedTextField: isEditable && flag("focused"))
    }

    /// The frame in dp of bounds such as `[0,0][1344,2992]`, in pixels.
    private func frame(_ bounds: String?) -> CGRect {
        let numbers = (bounds ?? "").matches(of: #/-?\d+/#).compactMap { Double($0.output) }
        guard numbers.count == 4 else {
            return .zero
        }

        return CGRect(x: numbers[0] / self.scale, y: numbers[1] / self.scale,
                      width: (numbers[2] - numbers[0]) / self.scale,
                      height: (numbers[3] - numbers[1]) / self.scale)
    }
}
