#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Foundation
import HammerAgentCore

/// An element a system driver reads from the device's whole screen, from outside the app.
protocol ScreenElement {
    /// The kind of element, such as `Button`.
    var type: String { get }
    var identifier: String? { get }
    var label: String? { get }
    var value: String? { get }

    /// The agent's trait names for the element, so queries read the same in every driver.
    var traits: [String] { get }

    /// The frame in screen points, or dp on Android.
    var frame: CGRect { get }
    var children: [Self] { get }

    /// Whether the element is a password field.
    var isSecure: Bool { get }

    /// The ways the element scrolls, `forward` and `backward`.
    var scrollDirections: [String] { get }
}

extension ScreenElement {
    var isSecure: Bool {
        return false
    }

    var scrollDirections: [String] {
        return []
    }

    var flattened: [Self] {
        return [self] + self.children.flatMap(\.flattened)
    }
}

/// The element or point a system driver's command acts on, decoded from its target arguments.
struct ScreenTarget: Decodable {
    let identifier: String?
    let label: String?
    let value: String?
    let traits: [String]?
    let x: Double?
    let y: Double?

    /// The element to look for, or nil for a point.
    ///
    /// - parameter traitNames: The traits the driver's elements can have.
    func query(traitNames: [String]) throws -> ElementQuery? {
        let traits = self.traits ?? []
        guard self.identifier != nil || self.label != nil || self.value != nil || !traits.isEmpty else {
            return nil
        }

        guard self.x == nil && self.y == nil else {
            throw ClientError.invalidArguments("The target has both an element and a point", hint: """
                Pass only one: any of identifier, label, value and traits, or x and y
                """)
        }

        if let unknown = traits.first(where: { !traitNames.contains($0) }) {
            let suggestion = closestMatch(to: unknown, in: traitNames).map { ", did you mean \($0)?" } ?? ""
            throw ClientError.invalidArguments("Unknown trait \"\(unknown)\"\(suggestion)",
                                               hint: "The traits are \(traitNames.joined(separator: ", "))")
        }

        return ElementQuery(identifier: self.identifier, label: self.label, value: self.value, traits: traits)
    }

    /// The point, or nil when the target has none.
    func point() throws -> CGPoint? {
        switch (self.x, self.y) {
        case (.some(let x), .some(let y)):
            return CGPoint(x: x, y: y)
        case (.none, .none):
            return nil
        default:
            throw ClientError.invalidArguments("Only one of x and y was passed",
                                               hint: "Pass both, in the coordinates of describe's frames")
        }
    }
}

/// Matches elements like the agent's accessibility queries: every property given must match.
struct ElementQuery {
    let identifier: String?
    let label: String?
    let value: String?
    let traits: [String]

    func element<Element: ScreenElement>(in root: Element) throws -> Element {
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
            let buttons = elements.filter { $0.traits.contains("button") }.compactMap(\.label.nonEmpty)
            throw ClientError.failed(.init(
                error: "Unable to find element: \(self)", code: .notFound,
                hint: "Call describe to see the elements on screen\(Self.listing(buttons))"))
        }

        return element
    }

    /// The most buttons a not found hint names, so a long list doesn't flood the error.
    static let hintButtonLimit = 10

    static func listing(_ buttons: [String]) -> String {
        guard !buttons.isEmpty else {
            return ""
        }

        let named = buttons.prefix(self.hintButtonLimit).map { "\"\($0)\"" }.joined(separator: ", ")
        let more = buttons.count > self.hintButtonLimit
            ? " and \(buttons.count - self.hintButtonLimit) more" : ""
        return ". The buttons on screen are \(named)\(more)"
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
struct DescribedElement: Encodable {
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
    let secure: Bool?
    let scroll: [String]?
    let frame: Frame
    let children: [DescribedElement]?

    /// Converts an element to nodes, replacing the ones without accessibility information by their children.
    static func nodes<Element: ScreenElement>(for element: Element) -> [DescribedElement] {
        let children = element.children.flatMap { Self.nodes(for: $0) }
        let traits = element.traits
        guard element.identifier.nonEmpty != nil || element.label.nonEmpty != nil
            || element.value.nonEmpty != nil || !traits.isEmpty || !element.scrollDirections.isEmpty
        else {
            return children
        }

        let frame = element.frame
        let node = DescribedElement(
            type: element.type, identifier: element.identifier.nonEmpty, label: element.label.nonEmpty,
            value: element.value.nonEmpty, traits: traits.isEmpty ? nil : traits,
            secure: element.isSecure ? true : nil,
            scroll: element.scrollDirections.isEmpty ? nil : element.scrollDirections,
            frame: Frame(x: frame.minX.rounded, y: frame.minY.rounded, width: frame.width.rounded,
                         height: frame.height.rounded),
            children: children.isEmpty ? nil : children)
        return [node]
    }

    /// The describe output for the screen's root elements.
    static func encode<Element: ScreenElement>(_ roots: [Element]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try encoder.encode(roots.flatMap { Self.nodes(for: $0) })
    }
}

extension ClientError {
    static func invalidArguments(_ description: String, hint: String) -> ClientError {
        return .failed(AgentErrorBody(error: description, code: .invalidArguments, hint: hint),
                       isInvalidCall: true)
    }
}

extension Optional where Wrapped == String {
    /// The string, or nil when it is only whitespace, like the label of SpringBoard's root element.
    var nonEmpty: String? {
        return self?.trimmingCharacters(in: .whitespaces).isEmpty == false ? self : nil
    }
}

extension CGFloat {
    /// The value rounded to a tenth of a point.
    fileprivate var rounded: Double {
        return (Double(self) * 10).rounded() / 10
    }
}
