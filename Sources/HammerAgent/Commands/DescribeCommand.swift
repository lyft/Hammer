import Foundation
import Hammer
import HammerAgentCore
import WebKit

struct DescribeCommand: AgentCommand {
    struct Arguments: Decodable {
        var all: Bool?
    }

    /// A view or element in the output, leaving out empty and default values to keep it short.
    struct Node: Encodable {
        struct Frame: Encodable {
            let x: Double
            let y: Double
            let width: Double
            let height: Double
        }

        let ref: String
        let type: String
        let identifier: String?
        let label: String?
        let value: String?
        let traits: [String]?
        let frame: Frame
        let hittable: Bool
        let children: [Node]?
    }

    let descriptor = BuiltinCommands.describe

    func run(_ arguments: Arguments, in context: AgentContext) async throws -> [Node] {
        let eventGenerator = try await context.eventGenerator()
        let snapshot = eventGenerator.elementSnapshot()
        context.references.removeReleased()
        let webElements = await self.webElements(in: snapshot, window: eventGenerator.window)
        return self.nodes(for: snapshot, includeAll: arguments.all ?? false, webElements: webElements,
                          in: context)
    }

    /// Reads the visible elements of the pages in the snapshot's web views, by web view.
    private func webElements(in snapshot: ElementSnapshot, window: UIWindow) async
        -> [ObjectIdentifier: [WebContent.Element]]
    {
        func webViews(in snapshot: ElementSnapshot) -> [WKWebView] {
            if let webView = snapshot.element.object as? WKWebView {
                return snapshot.isVisible ? [webView] : []
            }

            return snapshot.children.flatMap(webViews)
        }

        var elements = [ObjectIdentifier: [WebContent.Element]]()
        for webView in webViews(in: snapshot) {
            // A page that can't be read, such as one still loading, has no elements to show
            let pageElements = (try? await WebContent.elements(in: webView, window: window)) ?? []
            elements[ObjectIdentifier(webView)] = pageElements.filter(\.isVisible)
        }

        return elements
    }

    /// Converts the snapshot to nodes, replacing the ones left out with their children. Web views keep their
    /// node, with their page's elements as its children.
    private func nodes(for snapshot: ElementSnapshot, includeAll: Bool,
                       webElements: [ObjectIdentifier: [WebContent.Element]],
                       in context: AgentContext) -> [Node]
    {
        let pageElements = webElements[ObjectIdentifier(snapshot.element.object)]
        let pageNodes = (pageElements ?? []).map { self.node(for: $0, in: context) }
        let children = snapshot.children.flatMap {
            self.nodes(for: $0, includeAll: includeAll, webElements: webElements, in: context)
        } + pageNodes
        let traits = snapshot.traits.names
        let hasInformation = snapshot.identifier.nonEmpty != nil || snapshot.label.nonEmpty != nil
            || snapshot.value.nonEmpty != nil || !traits.isEmpty
        guard snapshot.isVisible && (includeAll || hasInformation || pageElements != nil) else {
            return children
        }

        let node = Node(ref: context.ref(for: snapshot.element),
                        type: String(describing: type(of: snapshot.element.object)),
                        identifier: snapshot.identifier.nonEmpty,
                        label: snapshot.label.nonEmpty, value: snapshot.value.nonEmpty,
                        traits: traits.isEmpty ? nil : traits, frame: Node.Frame(snapshot.frame),
                        hittable: snapshot.isHittable, children: children.isEmpty ? nil : children)
        return [node]
    }

    private func node(for element: WebContent.Element, in context: AgentContext) -> Node {
        let traits = element.traits.names
        return Node(ref: context.ref(for: element), type: element.type, identifier: element.identifier,
                    label: element.label, value: element.value, traits: traits.isEmpty ? nil : traits,
                    frame: Node.Frame(element.frame), hittable: element.isHittable, children: nil)
    }
}

extension DescribeCommand.Node.Frame {
    fileprivate init(_ frame: CGRect) {
        self.init(x: frame.minX.rounded, y: frame.minY.rounded, width: frame.width.rounded,
                  height: frame.height.rounded)
    }
}

extension Optional where Wrapped == String {
    fileprivate var nonEmpty: String? {
        return self?.isEmpty == false ? self : nil
    }
}

extension CGFloat {
    /// The value rounded to a tenth of a point.
    fileprivate var rounded: Double {
        return (Double(self) * 10).rounded() / 10
    }
}
