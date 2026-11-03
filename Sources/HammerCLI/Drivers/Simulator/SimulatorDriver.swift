import CoreGraphics
import Foundation
import HammerAgentCore

/// Runs commands on the simulator's whole screen from the Mac, like a person using Simulator.app, so they
/// reach system UI the app's agent can't, such as permission alerts.
struct SimulatorDriver: Driver {
    /// The simulator to drive, or nil for `HAMMER_SIMULATOR_UDID` or the only booted one.
    let udid: String?

    func catalog() async -> DriverCatalog {
        return DriverCatalog(commands: SimulatorCommands.all, note: nil)
    }

    func callableCommands() async throws -> [CommandDescriptor] {
        return SimulatorCommands.all
    }

    func run(_ name: String, arguments: [String: JSONValue]) async throws -> Data {
        guard let descriptor = SimulatorCommands.all.first(where: { $0.name == name }) else {
            let names = SimulatorCommands.all.map(\.name).joined(separator: ", ")
            throw ClientError.failed(.init(error: "\(name) does not run on the simulator's screen",
                                           code: .unknownCommand,
                                           hint: "Only \(names) do. Run \(name) in the app instead"),
                                     isInvalidCall: true)
        }

        do {
            try descriptor.validate(arguments)
        } catch let error as ArgumentsError {
            throw ClientError.invalidArguments(error.description, hint: error.hint)
        }

        let device = try CoreSimulator.device(udid: self.udid)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        switch descriptor.name {
        case SimulatorCommands.tap.name:
            let arguments = try JSONValue.object(arguments).decode(as: TapArguments.self)
            try await self.tap(arguments, on: device)
            return Data("{}".utf8)
        default:
            let root = try await SimulatorAccessibility.snapshot(of: device)
            return try encoder.encode(DescribedElement.nodes(for: root))
        }
    }

    private func tap(_ arguments: TapArguments, on device: SimDevice) async throws {
        guard arguments.count ?? 1 > 0 else {
            throw ClientError.invalidArguments("Invalid count \(arguments.count ?? 0), expected 1 or more",
                                               hint: "Use 1 for a tap and 2 for a double tap")
        }

        let point: CGPoint
        if let query = try arguments.query() {
            let root = try await SimulatorAccessibility.snapshot(of: device)
            let element = try query.element(in: root)
            point = CGPoint(x: element.frame.midX, y: element.frame.midY)
        } else {
            point = try arguments.point() ?? CGPoint(x: device.screenSize.width / 2,
                                                     y: device.screenSize.height / 2)
        }

        try await SimulatorHID(device: device).tap(at: point, count: arguments.count ?? 1)
    }
}

private struct TapArguments: Decodable {
    let identifier: String?
    let label: String?
    let value: String?
    let traits: [String]?
    let x: Double?
    let y: Double?
    let count: Int?

    /// The element to look for, or nil for a point.
    func query() throws -> ElementQuery? {
        let traits = self.traits ?? []
        guard self.identifier != nil || self.label != nil || self.value != nil || !traits.isEmpty else {
            return nil
        }

        guard self.x == nil && self.y == nil else {
            throw ClientError.invalidArguments("The target has both an element and a point", hint: """
                Pass only one: any of identifier, label, value and traits, or x and y
                """)
        }

        let names = SimulatorCommands.traitNames
        if let unknown = traits.first(where: { !names.contains($0) }) {
            let suggestion = closestMatch(to: unknown, in: names).map { ", did you mean \($0)?" } ?? ""
            throw ClientError.invalidArguments("Unknown trait \"\(unknown)\"\(suggestion)",
                                               hint: "The traits are \(names.joined(separator: ", "))")
        }

        return ElementQuery(identifier: self.identifier, label: self.label, value: self.value, traits: traits)
    }

    /// The point to tap, or nil for the center of the screen.
    func point() throws -> CGPoint? {
        switch (self.x, self.y) {
        case (.some(let x), .some(let y)):
            return CGPoint(x: x, y: y)
        case (.none, .none):
            return nil
        default:
            throw ClientError.invalidArguments("Only one of x and y was passed",
                                               hint: "Pass both, in screen points like describe's frames")
        }
    }
}

/// Matches elements like the agent's accessibility queries: every property given must match.
private struct ElementQuery {
    let identifier: String?
    let label: String?
    let value: String?
    let traits: [String]

    func element(in root: SystemElement) throws -> SystemElement {
        let elements = root.flattened
        let matches = elements.filter { element in
            (self.identifier == nil || element.identifier == self.identifier)
                && (self.label == nil || element.label == self.label)
                && (self.value == nil || element.value == self.value)
                && Set(self.traits).isSubset(of: element.traits)
        }

        guard matches.count < 2 else {
            throw ClientError.failed(.init(
                error: "\(matches.count) elements match \(self)", code: .ambiguousTarget,
                hint: "Add more of identifier, label, value and traits, or tap one's point from describe"))
        }

        guard let element = matches.first else {
            let buttons = elements.filter { $0.traits.contains("button") }.compactMap(\.label)
            let onScreen = buttons.isEmpty ? "" : ". The buttons on screen are "
                + buttons.map { "\"\($0)\"" }.joined(separator: ", ")
            throw ClientError.failed(.init(error: "Unable to find element: \(self)", code: .notFound,
                                           hint: "Call describe to see the elements on screen\(onScreen)"))
        }

        return element
    }
}

extension ElementQuery: CustomStringConvertible {
    var description: String {
        let properties = [("identifier", self.identifier), ("label", self.label), ("value", self.value)]
            .compactMap { name, value in value.map { "\(name) \"\($0)\"" } }
        let traits = self.traits.isEmpty ? [] : ["traits \(self.traits.joined(separator: ","))"]
        return (properties + traits).joined(separator: ", ")
    }
}

/// An element in describe's output, leaving out empty values like the agent's describe.
private struct DescribedElement: Encodable {
    struct Frame: Encodable {
        let x: Double
        let y: Double
        let width: Double
        let height: Double
    }

    let type: String
    let identifier: String?
    let label: String?
    let value: String?
    let traits: [String]?
    let frame: Frame
    let children: [DescribedElement]?

    /// Converts an element to nodes, replacing the ones without accessibility information by their children.
    static func nodes(for element: SystemElement) -> [DescribedElement] {
        let children = element.children.flatMap(Self.nodes)
        let traits = element.traits
        guard element.identifier.nonEmpty != nil || element.label.nonEmpty != nil
            || element.value.nonEmpty != nil || !traits.isEmpty
        else {
            return children
        }

        let frame = element.frame
        let node = DescribedElement(
            type: element.type, identifier: element.identifier.nonEmpty, label: element.label.nonEmpty,
            value: element.value.nonEmpty, traits: traits.isEmpty ? nil : traits,
            frame: Frame(x: frame.minX.rounded, y: frame.minY.rounded, width: frame.width.rounded,
                         height: frame.height.rounded),
            children: children.isEmpty ? nil : children)
        return [node]
    }
}

extension SystemElement {
    private static let traitsByRole = [
        "AXButton": "button", "AXLink": "link", "AXHeading": "header", "AXImage": "image",
        "AXStaticText": "staticText", "AXSearchField": "searchField",
    ]

    /// The role without the `AX` prefix of macOS accessibility roles, such as `Button`.
    fileprivate var type: String {
        return self.role.hasPrefix("AX") ? String(self.role.dropFirst(2)) : self.role
    }

    /// The agent's trait names for the element's role, so queries read the same in both drivers.
    fileprivate var traits: [String] {
        return Self.traitsByRole[self.role].map { [$0] } ?? []
    }

    fileprivate var flattened: [SystemElement] {
        return [self] + self.children.flatMap(\.flattened)
    }
}

extension ClientError {
    fileprivate static func invalidArguments(_ description: String, hint: String) -> ClientError {
        return .failed(AgentErrorBody(error: description, code: .invalidArguments, hint: hint),
                       isInvalidCall: true)
    }
}

extension Optional where Wrapped == String {
    /// The string, or nil when it is only whitespace, like the label of SpringBoard's root element.
    fileprivate var nonEmpty: String? {
        return self?.trimmingCharacters(in: .whitespaces).isEmpty == false ? self : nil
    }
}

extension CGFloat {
    /// The value rounded to a tenth of a point.
    fileprivate var rounded: Double {
        return (Double(self) * 10).rounded() / 10
    }
}
