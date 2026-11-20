import Foundation
import Hammer
import HammerAgentCore
import UIKit

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
        /// Why a web view's page couldn't be read, such as when it doesn't answer, so a page that couldn't
        /// be read doesn't look empty.
        var pageError: String?
        let children: [Node]?
    }

    let descriptor = BuiltinCommands.describe

    func run(_ arguments: Arguments, in context: AgentContext) async throws -> [Node] {
        let eventGenerator = try await context.eventGenerator()
        let snapshot = eventGenerator.elementSnapshot()
        context.references.removeReleased()
        let pageNodes = await self.pageNodes(in: eventGenerator.window, context: context)
        return self.nodes(for: snapshot, includeAll: arguments.all ?? false, pageNodes: pageNodes,
                          in: context)
    }

    /// Reads the pages of the window's web views at the same time, and returns their visible elements' nodes
    /// by web view.
    private func pageNodes(in window: UIWindow, context: AgentContext) async
        -> [ObjectIdentifier: Result<[Node], AgentError>]
    {
        let pages = await WebContent.pages(of: WebContent.webViews(in: window), window: window)
        return Dictionary(uniqueKeysWithValues: pages.map { page in
            (ObjectIdentifier(page.webView), page.elements.map { elements in
                let visible = elements.filter(\.isVisible)
                return zip(visible, context.refs(for: visible)).map { self.node(for: $0, ref: $1) }
            })
        })
    }

    /// Converts the snapshot to nodes, replacing the ones left out with their children. Web views keep their
    /// node, with their page's elements as its children.
    private func nodes(for snapshot: ElementSnapshot, includeAll: Bool,
                       pageNodes: [ObjectIdentifier: Result<[Node], AgentError>],
                       in context: AgentContext) -> [Node]
    {
        let pageElements = pageNodes[ObjectIdentifier(snapshot.element.object)]
        let children = snapshot.children.flatMap {
            self.nodes(for: $0, includeAll: includeAll, pageNodes: pageNodes, in: context)
        } + ((try? pageElements?.get()) ?? [])
        let traits = snapshot.traits.names
        let hasInformation = snapshot.identifier.nonEmpty != nil || snapshot.label.nonEmpty != nil
            || snapshot.value.nonEmpty != nil || !traits.isEmpty
        guard snapshot.isVisible && (includeAll || hasInformation || pageElements != nil) else {
            return children
        }

        var pageError: String?
        if case .failure(let error) = pageElements {
            pageError = error.description
        }

        let node = Node(ref: context.ref(for: snapshot.element),
                        type: String(describing: type(of: snapshot.element.object)),
                        identifier: snapshot.identifier.nonEmpty,
                        label: snapshot.label.nonEmpty, value: snapshot.value.nonEmpty,
                        traits: traits.isEmpty ? nil : traits, frame: Node.Frame(snapshot.frame),
                        hittable: snapshot.isHittable, pageError: pageError,
                        children: children.isEmpty ? nil : children)
        return [node]
    }

    private func node(for element: WebContent.Element, ref: String) -> Node {
        let traits = element.traits.names
        return Node(ref: ref, type: element.type, identifier: element.identifier,
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
