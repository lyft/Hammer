import UIKit

/// A view or an accessibility element that is not a view, such as an element of a SwiftUI view.
@MainActor
struct AccessibilityElement {
    /// The view or element.
    let object: NSObject

    /// The view itself, or the view the element belongs to.
    let containerView: UIView

    /// The view, or nil if the element is not a view.
    var view: UIView? {
        return self.object as? UIView
    }

    /// If the element is a control or has traits of an element that performs an action.
    var isActionable: Bool {
        return self.object is UIControl
            || !self.object.accessibilityTraits.isDisjoint(with: [.button, .link, .adjustable])
    }

    /// The element's frame in the window's coordinates.
    ///
    /// - parameter window: The window the element is in.
    ///
    /// - returns: The frame.
    func frame(in window: UIWindow) -> CGRect {
        window.screen.coordinateSpace.convert(self.object.accessibilityFrame, to: window)
    }

    /// The point a tap activates the element at in the window's coordinates, such as a toggle's switch.
    ///
    /// - parameter window: The window the element is in.
    ///
    /// - returns: The point.
    func activationPoint(in window: UIWindow) -> CGPoint {
        window.screen.coordinateSpace.convert(self.object.accessibilityActivationPoint, to: window)
    }
}

extension EventGenerator {
    /// Searches the views and the accessibility elements that are not views, such as SwiftUI's, for the ones
    /// that match the query. The elements only exist while the accessibility engine is active.
    ///
    /// NOTE: This uses a level order traversal with complexity O(n), where n is number of nodes in the tree.
    ///
    /// - parameter query: The query to match.
    ///
    /// - returns: The matching views followed by the matching elements that are not views.
    func accessibilityElements(matching query: AccessibilityQuery) -> [AccessibilityElement] {
        var views = [AccessibilityElement]()
        var elements = [AccessibilityElement]()
        var visited = Set<ObjectIdentifier>()

        // Views are reached through their subviews, after SwiftUI sets the identifier of hosted views, like
        // text fields, while it builds the elements of their container.
        func search(_ object: NSObject, in containerView: UIView) {
            for element in object.accessibilityChildren where !(element is UIView) {
                guard visited.insert(ObjectIdentifier(element)).inserted else {
                    continue
                }

                if query.matches(element) {
                    elements.append(AccessibilityElement(object: element, containerView: containerView))
                }

                search(element, in: containerView)
            }
        }

        var queue: [UIView] = [self.window]
        while !queue.isEmpty {
            let levelQueue = queue
            queue = []

            for view in levelQueue {
                search(view, in: view)
                if query.matches(view) {
                    views.append(AccessibilityElement(object: view, containerView: view))
                }

                queue.append(contentsOf: view.subviews)
            }
        }

        return views + elements
    }

    /// Finds the view or accessibility element to interact with for the query.
    ///
    /// Matches that activate at the same point, like a button and its title label, count as one. From the
    /// rest it prefers the visible ones and then the actionable ones.
    ///
    /// - parameter query:     The query to match.
    /// - parameter viewsOnly: If only views can match.
    ///
    /// - throws: `HammerError.multipleElementsFound` if it can't choose and `throwOnMultipleMatches` is set.
    ///
    /// - returns: The element, or nil if there is none.
    func accessibilityElement(matching query: AccessibilityQuery,
                              viewsOnly: Bool = false) throws -> AccessibilityElement?
    {
        var targets = [AccessibilityElement]()
        for element in self.accessibilityElements(matching: query) where !viewsOnly || element.view != nil {
            let point = element.activationPoint(in: self.window)
            if !targets.contains(where: { $0.activationPoint(in: self.window).distance(to: point) < 1 }) {
                targets.append(element)
            }
        }

        let visibleTargets = targets.filter { self.isVisible($0, visibility: .partial) }
        targets = visibleTargets.isEmpty ? targets : visibleTargets
        let actionableTargets = targets.filter(\.isActionable)
        targets = actionableTargets.isEmpty ? targets : actionableTargets

        if targets.count > 1 && self.settings.throwOnMultipleMatches {
            throw HammerError.multipleElementsFound(query: query, count: targets.count)
        }

        return targets.first
    }
}

@MainActor
extension NSObject {
    fileprivate var accessibilityChildren: [NSObject] {
        if let elements = self.accessibilityElements as? [NSObject] {
            return elements
        }

        // Elements without children report `NSNotFound`
        let count = self.accessibilityElementCount()
        guard count != NSNotFound, count > 0 else {
            return []
        }

        return (0..<count).compactMap { self.accessibilityElement(at: $0) as? NSObject }
    }

    // SwiftUI's elements have an identifier without declaring `UIAccessibilityIdentification`
    var accessibilityIdentifierValue: String? {
        let selector = #selector(getter: UIAccessibilityIdentification.accessibilityIdentifier)
        guard self.responds(to: selector) else {
            return nil
        }

        return self.value(forKey: "accessibilityIdentifier") as? String
    }
}
