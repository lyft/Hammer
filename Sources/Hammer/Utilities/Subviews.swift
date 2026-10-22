import Foundation
import UIKit

extension EventGenerator {
    /// How to calculate visibility of a view
    public enum Visibility {
        /// Any part of the view is visible
        case partial

        /// The center point of the view is visible
        case center

        /// The whole view is visible
        case full
    }

    /// Searches the view's subviews recursively for the first one that has the specified identifier.
    ///
    /// NOTE: This uses a level order traversal with complexity O(n), where n is number of nodes in the tree.
    ///
    /// - parameter accessibilityIdentifier: The identifier to match.
    ///
    /// - throws: And error if the view is not found.
    ///
    /// - returns: The view.
    public func viewWithIdentifier(_ accessibilityIdentifier: String) throws -> UIView {
        var queue: [UIView] = [self.window]
        while !queue.isEmpty {
            let levelQueue = queue
            queue = []

            for node in levelQueue {
                if node.accessibilityIdentifier == accessibilityIdentifier {
                    return node
                }

                queue.append(contentsOf: node.subviews)
            }
        }

        throw HammerError.unableToFindView(identifier: accessibilityIdentifier)
    }

    /// Searches the view's subviews recursively for the first one that has the specified identifier.
    ///
    /// NOTE: This uses a level order traversal with complexity O(n), where n is number of nodes in the tree.
    ///
    /// - parameter accessibilityIdentifier: The identifier to match.
    /// - parameter type:                    The type of the view.
    ///
    /// - throws: And error if the view is not found or is of an invalid type.
    ///
    /// - returns: The view.
    public func viewWithIdentifier<T: UIView>(_ accessibilityIdentifier: String,
                                              ofType type: T.Type) throws -> T
    {
        let view = try self.viewWithIdentifier(accessibilityIdentifier)
        if let typedView = view as? T {
            return typedView
        } else {
            throw HammerError.invalidViewType(identifier: accessibilityIdentifier,
                                              type: String(describing: Swift.type(of: view)),
                                              expected: String(describing: type))
        }
    }

    /// Searches the view's subviews recursively for the first one that has the specified identifier. If the
    /// view does not exist it will check again every frame until the specified timeout.
    ///
    /// NOTE: This uses a level order traversal with complexity O(n), where n is number of nodes in the tree.
    ///
    /// - parameter accessibilityIdentifier: The identifier to match.
    /// - parameter timeout:                 The maximum time to wait for the view.
    ///
    /// - throws: And error if the view is not found.
    ///
    /// - returns: The view.
    public func viewWithIdentifier(_ accessibilityIdentifier: String,
                                   timeout: TimeInterval) async throws -> UIView
    {
        try await self.viewWithIdentifier(accessibilityIdentifier, ofType: UIView.self, timeout: timeout)
    }

    /// Searches the view's subviews recursively for the first one that has the specified identifier. If the
    /// view does not exist it will check again every frame until the specified timeout.
    ///
    /// NOTE: This uses a level order traversal with complexity O(n), where n is number of nodes in the tree.
    ///
    /// - parameter accessibilityIdentifier: The identifier to match.
    /// - parameter type:                    The type of the view.
    /// - parameter timeout:                 The maximum time to wait for the view.
    ///
    /// - throws: And error if the view is not found.
    ///
    /// - returns: The view.
    public func viewWithIdentifier<T: UIView>(_ accessibilityIdentifier: String, ofType type: T.Type,
                                              timeout: TimeInterval) async throws -> T
    {
        do {
            return try await self.waitUntilExists(try self.existingView(accessibilityIdentifier, type),
                                                  timeout: timeout)
        } catch HammerError.waitConditionTimeout {
            throw HammerError.unableToFindView(identifier: accessibilityIdentifier)
        }
    }

    /// Searches for the view with the specified identifier, returning nil instead of throwing when it is not
    /// in the hierarchy yet.
    ///
    /// - parameter accessibilityIdentifier: The identifier to match.
    /// - parameter type:                    The type of the view.
    ///
    /// - throws: An error if the view is of an invalid type.
    ///
    /// - returns: The view, or nil if it is not in the hierarchy.
    private func existingView<T: UIView>(_ accessibilityIdentifier: String, _ type: T.Type) throws -> T? {
        do {
            return try self.viewWithIdentifier(accessibilityIdentifier, ofType: type)
        } catch HammerError.unableToFindView {
            return nil
        }
    }

    /// Returns if a view or SwiftUI element with the specified identifier exists.
    ///
    /// - parameter accessibilityIdentifier: The identifier to check.
    ///
    /// - returns: If the view or element exists
    public func viewExists(_ accessibilityIdentifier: String) -> Bool {
        return (try? self.viewWithIdentifier(accessibilityIdentifier)) != nil
            || self.accessibilityElement(withIdentifier: accessibilityIdentifier) != nil
    }

    /// Returns if the specified view or SwiftUI element is visible.
    ///
    /// NOTE: This will also return false if the view for the accessibility identifier is not found.
    ///
    /// - parameter accessibilityIdentifier: The identifier to check.
    /// - parameter visibility:              How determine if the view is visible.
    ///
    /// - returns: If the view is visible
    public func viewIsVisible(_ accessibilityIdentifier: String, visibility: Visibility = .partial) -> Bool {
        if let view = try? self.viewWithIdentifier(accessibilityIdentifier) {
            return self.viewIsVisible(view, visibility: visibility)
        }

        guard let element = self.accessibilityElement(withIdentifier: accessibilityIdentifier) else {
            return false
        }

        return self.elementIsVisible(element, visibility: visibility)
    }

    /// Returns if the specified view is visible.
    ///
    /// - parameter view:       The view to check.
    /// - parameter visibility: How determine if the view is visible.
    ///
    /// - returns: If the view is visible
    public func viewIsVisible(_ view: UIView, visibility: Visibility = .partial) -> Bool {
        return view.isVisible(inWindow: self.window, visibility: visibility)
    }

    /// Returns if the specified rect is visible.
    ///
    /// - parameter rect:       The rect in window coordinates
    /// - parameter visibility: How determine if the view is visible.
    ///
    /// - returns: If the rect is visible
    public func rectIsVisible(_ rect: CGRect, visibility: Visibility = .partial) -> Bool {
        return self.window.bounds.isVisible(rect, visibility: visibility)
    }

    /// Returns if the specified point is visible.
    ///
    /// - parameter point: The point in window coordinates
    ///
    /// - returns: If the point is visible
    public func pointIsVisible(_ point: CGPoint) -> Bool {
        return self.window.bounds.contains(point)
    }

    /// Returns if the specified view or SwiftUI element is hittable.
    ///
    /// NOTE: This will also return false if the view for the accessibility identifier is not found.
    ///
    /// - parameter accessibilityIdentifier: The identifier to check.
    /// - parameter point:                   A point to check if hittable in the view's coordinate space. If
    ///                                      nil, it will use the center of the view's visible area, or the
    ///                                      activation point of a SwiftUI element.
    ///
    /// - returns: If the view is hittable
    public func viewIsHittable(_ accessibilityIdentifier: String, atPoint point: CGPoint? = nil) -> Bool {
        if let view = try? self.viewWithIdentifier(accessibilityIdentifier) {
            return self.viewIsHittable(view, atPoint: point)
        }

        guard let element = self.accessibilityElement(withIdentifier: accessibilityIdentifier),
              self.elementIsVisible(element, visibility: .partial)
        else {
            return false
        }

        let elementOrigin = element.frame(in: self.window).origin
        let windowPoint = point.map { CGPoint(x: elementOrigin.x + $0.x, y: elementOrigin.y + $0.y) }
            ?? self.internalWindowHitPoint(forElement: element)
        return self.elementIsHittable(element, atWindowPoint: windowPoint)
    }

    /// Returns if the specified view is hittable.
    ///
    /// - parameter view:  The view to check.
    /// - parameter point: A point to check if hittable in the view's coordinate space. If nil, it will use
    ///                    the center of the view's visible area.
    ///
    /// - returns: If the view is hittable
    public func viewIsHittable(_ view: UIView, atPoint point: CGPoint? = nil) -> Bool {
        guard self.isWindowReady else {
            return false
        }

        guard self.viewIsVisible(view) else {
            return false
        }

        let point = point ?? {
            let windowHitPoint = self.internalWindowHitPoint(forView: view)
            return view.convert(windowHitPoint, from: self.window)
        }()

        // Check if hittable through standard piping
        let windowHitPoint = view.convert(point, to: self.window)
        guard let windowHitTest = self.window.hitTest(windowHitPoint, with: nil) else {
            // If the hit test returns nil there is no interactive view
            return false
        }

        if windowHitTest.isDescendant(of: view) {
            // If the hit test returns the target view or one of its subviews we know it is hittable
            return true
        } else if !view.isDescendant(of: windowHitTest) {
            // Another view covers the target and would receive the touch instead
            return false
        }

        // Recursive
        func viewIsHittable(currentView: UIView) -> Bool {
            guard currentView.isUserInteractionEnabled else {
                return false
            }

            let adjustedPoint = currentView.convert(point, from: view)
            guard currentView.point(inside: adjustedPoint, with: nil) else {
                return false
            }

            guard let superview = currentView.superview else {
                return currentView == self.window
            }

            return viewIsHittable(currentView: superview)
        }

        return viewIsHittable(currentView: view)
    }

    /// Returns if the specified point has a hittable view at that location.
    ///
    /// - parameter point: The point in window coordinates
    ///
    /// - returns: If the point is hittable
    public func pointIsHittable(_ point: CGPoint) -> Bool {
        guard self.isWindowReady else {
            return false
        }

        return self.window.hitTest(point, with: nil) != nil
    }

    /// Checks if the specified points have a hittable view at that location.
    ///
    /// - parameter points: The points in window coordinates
    ///
    /// - throws: If one of the points is not hittable
    func checkPointsAreHittable(_ points: [CGPoint]) throws {
        try self.checkWindowIsReady()

        if let nonHittablePoint = points.first(where: { !self.pointIsHittable($0) }) {
            throw HammerError.pointIsNotHittable(nonHittablePoint)
        }
    }

    /// Returns a valid hittable point in the specified view.
    ///
    /// - parameter view: The view to hit
    ///
    /// - throws: And error if the view is not in the same hierarchy, not visible or not hittable.
    ///
    /// - returns: If the view is hittable
    public func windowHitPoint(forView view: UIView) throws -> CGPoint {
        try self.checkWindowIsReady()

        guard view.isDescendant(of: self.window) else {
            throw HammerError.viewIsNotInHierarchy(view)
        }

        guard self.viewIsVisible(view) else {
            throw HammerError.viewIsNotVisible(view)
        }

        guard self.viewIsHittable(view) else {
            throw HammerError.viewIsNotHittable(view)
        }

        return self.internalWindowHitPoint(forView: view)
    }

    /// Returns a valid hittable point for the view or SwiftUI element with the specified identifier.
    ///
    /// - parameter accessibilityIdentifier: The identifier of the view or element to hit.
    ///
    /// - throws: And error if the view or element is not found, not visible or not hittable.
    ///
    /// - returns: The hittable point in window coordinates
    public func windowHitPoint(forIdentifier accessibilityIdentifier: String) throws -> CGPoint {
        try self.checkWindowIsReady()

        if let view = try? self.viewWithIdentifier(accessibilityIdentifier) {
            return try self.windowHitPoint(forView: view)
        }

        guard let element = self.accessibilityElement(withIdentifier: accessibilityIdentifier) else {
            throw HammerError.unableToFindView(identifier: accessibilityIdentifier)
        }

        guard self.elementIsVisible(element, visibility: .partial) else {
            throw HammerError.elementIsNotVisible(identifier: accessibilityIdentifier)
        }

        let windowPoint = self.internalWindowHitPoint(forElement: element)
        guard self.elementIsHittable(element, atWindowPoint: windowPoint) else {
            throw HammerError.elementIsNotHittable(identifier: accessibilityIdentifier)
        }

        return windowPoint
    }

    /// Returns if touches at the point reach the view the SwiftUI element belongs to.
    ///
    /// - parameter element:     The element to check.
    /// - parameter windowPoint: The point in window coordinates.
    ///
    /// - returns: If the element is hittable at the point
    private func elementIsHittable(_ element: AccessibilityElement,
                                   atWindowPoint windowPoint: CGPoint) -> Bool
    {
        let containerView = element.containerView
        let point = containerView.convert(windowPoint, from: self.window)
        return self.viewIsHittable(containerView, atPoint: point)
    }

    /// Returns if the SwiftUI element is visible, including within the views that clip it.
    ///
    /// - parameter element:    The element to check.
    /// - parameter visibility: How determine if the element is visible.
    ///
    /// - returns: If the element is visible
    private func elementIsVisible(_ element: AccessibilityElement, visibility: Visibility) -> Bool {
        guard self.viewIsVisible(element.containerView) else {
            return false
        }

        return self.visibleBounds(of: element.containerView)
            .isVisible(element.frame(in: self.window), visibility: visibility)
    }

    /// Returns the part of the window the view's content can show in, after its ancestors clip it.
    ///
    /// - parameter view: The view to check.
    ///
    /// - returns: The visible bounds in window coordinates
    private func visibleBounds(of view: UIView) -> CGRect {
        var bounds = self.window.bounds
        var currentView: UIView? = view
        while let clippingView = currentView, clippingView !== self.window {
            if clippingView.clipsToBounds {
                bounds = bounds.intersection(clippingView.convert(clippingView.bounds, to: self.window))
            }

            currentView = clippingView.superview
        }

        return bounds
    }

    /// Returns the point that taps the SwiftUI element without any validation, such as a toggle's switch.
    ///
    /// - parameter element: The element to hit
    ///
    /// - returns: A possible hittable point in window coordinates
    private func internalWindowHitPoint(forElement element: AccessibilityElement) -> CGPoint {
        let activationPoint = element.activationPoint(in: self.window)
        let visibleFrame = self.visibleBounds(of: element.containerView)
            .intersection(element.frame(in: self.window))
        return visibleFrame.contains(activationPoint) ? activationPoint : visibleFrame.center
    }

    /// Returns a possible hittable point in the specified view without any validation.
    ///
    /// - parameter view: The view to hit
    ///
    /// - returns: A possible hittable point
    private func internalWindowHitPoint(forView view: UIView) -> CGPoint {
        let viewBounds = view.convert(view.bounds, to: self.window)
        return self.window.bounds.intersection(viewBounds).center
    }
}
