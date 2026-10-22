import UIKit

/// The state of a view or an accessibility element that is not a view, and of its descendants.
@MainActor
public struct ElementSnapshot {
    /// The view or element.
    public let element: AccessibilityElement

    /// The accessibility identifier.
    public let identifier: String?

    /// The accessibility label.
    public let label: String?

    /// The accessibility value.
    public let value: String?

    /// The accessibility traits.
    public let traits: UIAccessibilityTraits

    /// The frame in the window's coordinates.
    public let frame: CGRect

    /// If any part of it is visible.
    public let isVisible: Bool

    /// If touches reach it.
    public let isHittable: Bool

    /// The accessibility elements that are not views followed by the subviews, back to front.
    public let children: [ElementSnapshot]
}

extension EventGenerator {
    /// Captures the window's visible views and the accessibility elements that are not views, such as
    /// SwiftUI's. The elements only exist while the accessibility engine is active.
    ///
    /// - returns: The snapshot of the window.
    public func elementSnapshot() -> ElementSnapshot {
        var visited = Set<ObjectIdentifier>()

        func snapshot(_ element: AccessibilityElement, children: [ElementSnapshot]) -> ElementSnapshot {
            let object = element.object
            return ElementSnapshot(element: element, identifier: object.accessibilityIdentifierValue,
                                   label: object.accessibilityLabel, value: object.accessibilityValue,
                                   traits: object.accessibilityTraits, frame: element.frame(in: self.window),
                                   isVisible: self.isVisible(element, visibility: .partial),
                                   isHittable: self.isHittable(element), children: children)
        }

        func elementSnapshots(of object: NSObject, in containerView: UIView) -> [ElementSnapshot] {
            return object.accessibilityChildren.compactMap { child in
                guard !(child is UIView), visited.insert(ObjectIdentifier(child)).inserted else {
                    return nil
                }

                return snapshot(AccessibilityElement(object: child, containerView: containerView),
                                children: elementSnapshots(of: child, in: containerView))
            }
        }

        func viewSnapshot(_ view: UIView) -> ElementSnapshot {
            let subviews = view.subviews.filter { !$0.isHidden && $0.alpha >= 0.01 }
            let children = elementSnapshots(of: view, in: view) + subviews.map(viewSnapshot)
            return snapshot(AccessibilityElement(object: view, containerView: view), children: children)
        }

        return viewSnapshot(self.window)
    }
}
