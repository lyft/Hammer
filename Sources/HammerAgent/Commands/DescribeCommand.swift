import Foundation
import Hammer
import HammerAgentCore

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
        let snapshot = try await context.eventGenerator().elementSnapshot()
        context.references.removeReleased()
        return self.nodes(for: snapshot, includeAll: arguments.all ?? false, in: context)
    }

    /// Converts the snapshot to nodes, replacing the ones left out with their children.
    private func nodes(for snapshot: ElementSnapshot, includeAll: Bool, in context: AgentContext) -> [Node] {
        let children = snapshot.children.flatMap { self.nodes(for: $0, includeAll: includeAll, in: context) }
        let traits = snapshot.traits.names
        let hasInformation = snapshot.identifier.nonEmpty != nil || snapshot.label.nonEmpty != nil
            || snapshot.value.nonEmpty != nil || !traits.isEmpty
        guard snapshot.isVisible && (includeAll || hasInformation) else {
            return children
        }

        let frame = snapshot.frame
        let node = Node(ref: context.ref(for: snapshot.element),
                        type: String(describing: type(of: snapshot.element.object)),
                        identifier: snapshot.identifier.nonEmpty,
                        label: snapshot.label.nonEmpty, value: snapshot.value.nonEmpty,
                        traits: traits.isEmpty ? nil : traits,
                        frame: Node.Frame(x: frame.minX.rounded, y: frame.minY.rounded,
                                          width: frame.width.rounded, height: frame.height.rounded),
                        hittable: snapshot.isHittable, children: children.isEmpty ? nil : children)
        return [node]
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
