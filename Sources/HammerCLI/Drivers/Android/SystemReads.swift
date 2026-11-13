#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Foundation
import HammerAgentCore

/// Fills in what the app's agent can't read, such as a web page, which describe marks `needsSystemRead`,
/// from the system helper's read of the app's windows.
///
/// The elements it adds have refs such as `s1a2b3c4d`, made from what each element is and where it is, so
/// no state is kept between calls: a command that passes one reads the screen again, and fails when the
/// element changed or moved, such as after the page scrolled.
enum SystemReads {
    /// The start of the refs of elements the system helper read. The agent's start with `e`.
    static let refPrefix = "s"

    /// How far apart, in dp, the agent's frame of a view and the helper's may be and still be the same view.
    static let frameTolerance: CGFloat = 1.5

    /// The frames of the nodes in describe's output whose content needs the system helper, in order.
    static func regions(in nodes: [JSONValue]) -> [CGRect] {
        return nodes.flatMap { node -> [CGRect] in
            guard case .object(let fields) = node else {
                return []
            }

            let own = fields["needsSystemRead"] == .bool(true) ? self.frame(of: fields) : nil
            return (own.map { [$0] } ?? []) + self.regions(in: self.children(of: fields))
        }
    }

    /// The describe nodes, with refs, of the helper's elements inside the view with the region's frame, or
    /// nil when the helper read no such view.
    static func content(of region: CGRect, in windows: [AndroidElement]) -> [JSONValue]? {
        let view = windows.flatMap(\.flattened).last { element in
            abs(element.frame.minX - region.minX) <= self.frameTolerance
                && abs(element.frame.minY - region.minY) <= self.frameTolerance
                && abs(element.frame.width - region.width) <= self.frameTolerance
                && abs(element.frame.height - region.height) <= self.frameTolerance
        }
        guard let view else {
            return nil
        }

        return self.withRefs(self.nodes(view.children))
    }

    /// The output with each marked node's content as its children, in the order of `contents`. A node whose
    /// content is nil keeps its mark, so the output says it wasn't read.
    static func merge(_ nodes: [JSONValue], contents: [[JSONValue]?]) -> [JSONValue] {
        var remaining = contents[...]
        return self.merge(nodes, remaining: &remaining)
    }

    /// The center of the element the ref names, or nil when no element on screen has it.
    static func point(of ref: String, in windows: [AndroidElement]) -> CGPoint? {
        let nodes = self.flattened(self.withRefs(self.nodes(windows)))
        return nodes.first { $0["ref"] == .string(ref) }.flatMap { self.frame(of: $0) }
            .map { CGPoint(x: $0.midX, y: $0.midY) }
    }

    /// The nodes in content that a query matches, as the agent matches them.
    static func matches(_ query: ElementQuery, in content: [JSONValue]) -> [[String: JSONValue]] {
        return self.flattened(content).filter { node in
            let traits = Set(node["traits"]?.arrayValue?.compactMap(\.stringValue) ?? [])
            return (query.identifier == nil || node["identifier"]?.stringValue == query.identifier)
                && (query.label == nil || node["label"]?.stringValue == query.label)
                && (query.value == nil || node["value"]?.stringValue == query.value)
                && Set(query.traits).isSubset(of: traits)
        }
    }

    static func frame(of fields: [String: JSONValue]) -> CGRect? {
        guard case .object(let frame)? = fields["frame"],
              let x = frame["x"]?.numberValue, let y = frame["y"]?.numberValue,
              let width = frame["width"]?.numberValue, let height = frame["height"]?.numberValue
        else {
            return nil
        }

        return CGRect(x: x, y: y, width: width, height: height)
    }

    private static func merge(_ nodes: [JSONValue], remaining: inout ArraySlice<[JSONValue]?>)
        -> [JSONValue]
    {
        return nodes.map { node in
            guard case .object(var fields) = node else {
                return node
            }

            let isMarked = fields["needsSystemRead"] == .bool(true)
            let children = self.merge(self.children(of: fields), remaining: &remaining)
            var added: [JSONValue] = []
            if isMarked, let content = remaining.popFirst() ?? nil {
                fields["needsSystemRead"] = nil
                added = content
            }

            fields["children"] = children.isEmpty && added.isEmpty ? nil : .array(children + added)
            return .object(fields)
        }
    }

    private static func nodes(_ elements: [AndroidElement]) -> [JSONValue] {
        let nodes = elements.flatMap { DescribedElement.nodes(for: $0) }
        guard let data = try? JSONEncoder().encode(nodes),
              let decoded = try? JSONDecoder().decode([JSONValue].self, from: data)
        else {
            return []
        }

        return decoded
    }

    private static func withRefs(_ nodes: [JSONValue]) -> [JSONValue] {
        return nodes.map { node in
            guard case .object(var fields) = node else {
                return node
            }

            let children = self.withRefs(self.children(of: fields))
            fields["children"] = children.isEmpty ? nil : .array(children)
            fields["ref"] = .string(self.ref(for: fields))
            return .object(fields)
        }
    }

    /// A ref from the element's own type, identifier, label, value and frame: FNV-1a, 32 bits.
    private static func ref(for fields: [String: JSONValue]) -> String {
        let frame = self.frame(of: fields).map { "\($0.minX),\($0.minY),\($0.width),\($0.height)" } ?? ""
        let key = ["type", "identifier", "label", "value"].map { fields[$0]?.stringValue ?? "" } + [frame]
        var hash: UInt32 = 0x811c_9dc5
        for byte in key.joined(separator: "\u{1F}").utf8 {
            hash = (hash ^ UInt32(byte)) &* 0x0100_0193
        }

        return self.refPrefix + String(format: "%08x", hash)
    }

    private static func children(of fields: [String: JSONValue]) -> [JSONValue] {
        return fields["children"]?.arrayValue ?? []
    }

    private static func flattened(_ nodes: [JSONValue]) -> [[String: JSONValue]] {
        return nodes.flatMap { node -> [[String: JSONValue]] in
            guard case .object(let fields) = node else {
                return []
            }

            return [fields] + self.flattened(self.children(of: fields))
        }
    }
}

extension JSONValue {
    fileprivate var arrayValue: [JSONValue]? {
        guard case .array(let array) = self else {
            return nil
        }

        return array
    }

    fileprivate var stringValue: String? {
        guard case .string(let string) = self else {
            return nil
        }

        return string
    }

    fileprivate var numberValue: Double? {
        guard case .number(let number) = self else {
            return nil
        }

        return number
    }
}
