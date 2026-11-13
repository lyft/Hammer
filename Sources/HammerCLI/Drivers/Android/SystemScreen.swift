#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Foundation
import HammerAgentCore

/// The whole screen of an Android device, read and driven through the system helper or through adb's
/// uiautomator and `input`. Both read into the same elements, so a command finds its target the same way.
protocol SystemScreen: Sendable {
    func metrics() async throws -> AndroidScreen.Metrics

    /// The windows on screen back to front, each with its accessibility nodes, in dp.
    func windows(scale: CGFloat) async throws -> [AndroidElement]

    func tap(_ point: CGPoint, metrics: AndroidScreen.Metrics) async throws

    func swipe(from start: CGPoint, to end: CGPoint, duration: TimeInterval, metrics: AndroidScreen.Metrics)
        async throws

    func type(_ text: String) async throws

    /// Presses a key by its `KeyEvent` name, such as `KEYCODE_BACK`.
    func press(keyCode: String) async throws

    /// A PNG of the screen, or of an area in dp, at `scale` pixels per dp.
    func png(area: CGRect?, scale: Double, metrics: AndroidScreen.Metrics) async throws -> Data
}

extension AndroidScreen: SystemScreen {
    func png(area: CGRect?, scale: Double, metrics: AndroidScreen.Metrics) async throws -> Data {
        let screenshot = try await self.screenshot()
        return try AndroidSystemDriver.png(screenshot, area: area, scale: scale, metrics: metrics)
    }
}

/// The screen through the system helper, which answers in pixels.
struct HelperScreen: SystemScreen {
    let client: AgentClient
    let adb: Adb
    let serial: String

    func metrics() async throws -> AndroidScreen.Metrics {
        return try await AndroidScreen(adb: self.adb, serial: self.serial).metrics()
    }

    func windows(scale: CGFloat) async throws -> [AndroidElement] {
        let output = try await self.client.run("describe", arguments: [:])
        return try HelperDump.windows(from: output, scale: scale)
    }

    /// The windows of one app, such as the one whose agent can't read a web view.
    func windows(of packageName: String, scale: CGFloat) async throws -> [AndroidElement] {
        let output = try await self.client.run("describe", arguments: ["package": .string(packageName)])
        return try HelperDump.windows(from: output, scale: scale)
    }

    func tap(_ point: CGPoint, metrics: AndroidScreen.Metrics) async throws {
        let (x, y) = metrics.pixel(point)
        _ = try await self.client.run("tap", arguments: ["x": .number(Double(x)), "y": .number(Double(y))])
    }

    func swipe(from start: CGPoint, to end: CGPoint, duration: TimeInterval, metrics: AndroidScreen.Metrics)
        async throws
    {
        let (x1, y1) = metrics.pixel(start)
        let (x2, y2) = metrics.pixel(end)
        _ = try await self.client.run("swipe", arguments: [
            "x": .number(Double(x1)), "y": .number(Double(y1)), "to_x": .number(Double(x2)),
            "to_y": .number(Double(y2)), "duration": .number(duration),
        ])
    }

    func type(_ text: String) async throws {
        _ = try await self.client.run("type_text", arguments: ["text": .string(text)])
    }

    func press(keyCode: String) async throws {
        _ = try await self.client.run("press_key", arguments: ["key": .string(keyCode)])
    }

    func png(area: CGRect?, scale: Double, metrics: AndroidScreen.Metrics) async throws -> Data {
        let dp = area ?? metrics.bounds
        guard dp.width > 0, dp.height > 0, metrics.bounds.intersects(dp) else {
            throw ClientError.failed(.init(error: "The area is off the screen", code: .failed))
        }

        var arguments: [String: JSONValue] = [
            "width": .number((dp.width * scale).rounded()), "height": .number((dp.height * scale).rounded()),
        ]
        if let area {
            let (x, y) = metrics.pixel(area.origin)
            arguments["area_x"] = .number(Double(x))
            arguments["area_y"] = .number(Double(y))
            arguments["area_width"] = .number((area.width * metrics.scale).rounded())
            arguments["area_height"] = .number((area.height * metrics.scale).rounded())
        }

        let output = try await self.client.run("screenshot", arguments: arguments)
        return try JSONDecoder().decode(AgentImage.self, from: output).data
    }
}

/// Reads the system helper's describe output, which has uiautomator's attribute names, into elements.
enum HelperDump {
    private struct Output: Decodable {
        let windows: [Window]
    }

    private struct Window: Decodable {
        let title: String?
        let package: String?
        let bounds: [Double]
        let root: Node
    }

    private struct Node: Decodable {
        let attributes: [String: String]
        let bounds: [Double]
        let flags: [String]
        let children: [Node]

        private enum CodingKeys: String, CodingKey {
            case className = "class"
            case text
            case description = "content-desc"
            case resourceID = "resource-id"
            case hint
            case bounds
            case flags
            case children
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            var attributes: [String: String] = [:]
            let names: [(CodingKeys, String)] = [
                (.className, "class"), (.text, "text"), (.description, "content-desc"),
                (.resourceID, "resource-id"), (.hint, "hint"),
            ]
            for (key, name) in names {
                attributes[name] = try container.decodeIfPresent(String.self, forKey: key)
            }
            self.flags = try container.decodeIfPresent([String].self, forKey: .flags) ?? []
            for flag in self.flags {
                if flag == "disabled" {
                    attributes["enabled"] = "false"
                } else {
                    attributes[flag] = "true"
                }
            }
            self.attributes = attributes
            self.bounds = try container.decode([Double].self, forKey: .bounds)
            self.children = try container.decodeIfPresent([Node].self, forKey: .children) ?? []
        }
    }

    /// The windows back to front, in dp.
    ///
    /// - throws: A `failed` error if the output isn't the helper's describe output.
    static func windows(from output: Data, scale: CGFloat) throws -> [AndroidElement] {
        let decoded: Output
        do {
            decoded = try JSONDecoder().decode(Output.self, from: output)
        } catch {
            throw ClientError.failed(.init(
                error: "The system helper's describe output is unreadable: \(error)", code: .failed))
        }

        return decoded.windows.map { window in
            AndroidElement(type: "Window", identifier: nil, label: window.title.nonEmpty ?? window.package,
                           value: nil, traits: [], frame: self.frame(window.bounds, scale: scale),
                           children: [self.element(window.root, scale: scale)])
        }
    }

    private static func element(_ node: Node, scale: CGFloat) -> AndroidElement {
        var attributes = node.attributes
        let bounds = node.bounds.map { Int($0) }
        attributes["bounds"] = bounds.count == 4
            ? "[\(bounds[0]),\(bounds[1])][\(bounds[2]),\(bounds[3])]" : nil
        let element = UIAutomatorDump.element(attributes, scale: scale)
        return AndroidElement(type: element.type, identifier: element.identifier, label: element.label,
                              value: element.value, traits: element.traits, frame: element.frame,
                              children: node.children.map { self.element($0, scale: scale) },
                              isFocusedTextField: element.isFocusedTextField, isSecure: element.isSecure,
                              scrollDirections: element.scrollDirections)
    }

    private static func frame(_ bounds: [Double], scale: CGFloat) -> CGRect {
        guard bounds.count == 4 else {
            return .zero
        }

        return CGRect(x: bounds[0] / scale, y: bounds[1] / scale, width: (bounds[2] - bounds[0]) / scale,
                      height: (bounds[3] - bounds[1]) / scale)
    }
}
