import UIKit

/// An accessibility element that is not a view, such as an element of a SwiftUI view.
@MainActor
struct AccessibilityElement {
    /// The element.
    let object: NSObject

    /// The view the element belongs to.
    let containerView: UIView

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
    /// Searches the accessibility elements that are not views, such as SwiftUI's, for the first one that has
    /// the specified identifier. They only exist while the accessibility engine is active.
    ///
    /// - parameter accessibilityIdentifier: The identifier to match.
    ///
    /// - returns: The element, or nil if there is none.
    func accessibilityElement(withIdentifier accessibilityIdentifier: String) -> AccessibilityElement? {
        var visited = Set<ObjectIdentifier>()

        // Views are reached through their subviews, so only the other elements are followed here. SwiftUI
        // sets the identifier of a hosted view, such as a text field, when it builds its elements.
        func search(_ object: NSObject, in containerView: UIView) -> AccessibilityElement? {
            for element in object.accessibilityChildren {
                if let view = element as? UIView {
                    if view.accessibilityIdentifier == accessibilityIdentifier {
                        return AccessibilityElement(object: view, containerView: view)
                    }

                    continue
                }

                guard visited.insert(ObjectIdentifier(element)).inserted else {
                    continue
                }

                if element.identifier == accessibilityIdentifier {
                    return AccessibilityElement(object: element, containerView: containerView)
                }

                if let found = search(element, in: containerView) {
                    return found
                }
            }

            return nil
        }

        var queue: [UIView] = [self.window]
        while !queue.isEmpty {
            let levelQueue = queue
            queue = []

            for view in levelQueue {
                if let found = search(view, in: view) {
                    return found
                }

                queue.append(contentsOf: view.subviews)
            }
        }

        return nil
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
    fileprivate var identifier: String? {
        let selector = #selector(getter: UIAccessibilityIdentification.accessibilityIdentifier)
        guard self.responds(to: selector) else {
            return nil
        }

        return self.value(forKey: "accessibilityIdentifier") as? String
    }
}
