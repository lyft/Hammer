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
    /// view does not exist it will check again multiple times until the specified timeout.
    ///
    /// NOTE: This uses a level order traversal with complexity O(n), where n is number of nodes in the tree.
    ///
    /// - parameter accessibilityIdentifier: The identifier to match.
    /// - parameter timeout:                 The maximum time to wait for the closure to return an object.
    /// - parameter checkInterval:           How often should the closure be checked.
    ///
    /// - throws: And error if the view is not found.
    ///
    /// - returns: The view.
    public func viewWithIdentifier(_ accessibilityIdentifier: String,
                                   timeout: TimeInterval,
                                   checkInterval: TimeInterval = 0.1) throws -> UIView
    {
        do {
            return try self.waitUntilExists({
                do {
                    return try self.viewWithIdentifier(accessibilityIdentifier)
                } catch HammerError.unableToFindView {
                    return nil
                } catch {
                    throw error
                }
            }(), timeout: timeout, checkInterval: checkInterval)
        } catch HammerError.waitConditionTimeout {
            throw HammerError.unableToFindView(identifier: accessibilityIdentifier)
        } catch {
            throw error
        }
    }

    /// Searches the view's subviews recursively for the first one that has the specified identifier. If the
    /// view does not exist it will check again multiple times until the specified timeout.
    ///
    /// NOTE: This uses a level order traversal with complexity O(n), where n is number of nodes in the tree.
    ///
    /// - parameter accessibilityIdentifier: The identifier to match.
    /// - parameter type:                    The type of the view.
    /// - parameter timeout:                 The maximum time to wait for the closure to return an object.
    /// - parameter checkInterval:           How often should the closure be checked.
    ///
    /// - throws: And error if the view is not found.
    ///
    /// - returns: The view.
    public func viewWithIdentifier<T: UIView>(_ accessibilityIdentifier: String, ofType type: T.Type,
                                              timeout: TimeInterval,
                                              checkInterval: TimeInterval = 0.1) throws -> T
    {
        do {
            return try self.waitUntilExists({
                do {
                    return try self.viewWithIdentifier(accessibilityIdentifier, ofType: type)
                } catch HammerError.unableToFindView {
                    return nil
                } catch {
                    throw error
                }
            }(), timeout: timeout, checkInterval: checkInterval)
        } catch HammerError.waitConditionTimeout {
            throw HammerError.unableToFindView(identifier: accessibilityIdentifier)
        } catch {
            throw error
        }
    }

    /// Returns if the specified view is visible.
    ///
    /// NOTE: This will also return false if the view for the accessibility identifier is not found.
    ///
    /// - parameter accessibilityIdentifier: The identifier to check.
    /// - parameter visibility:              How determine if the view is visible.
    ///
    /// - returns: If the view is visible
    public func viewIsVisible(_ accessibilityIdentifier: String, visibility: Visibility = .partial) -> Bool {
        guard let view = try? self.viewWithIdentifier(accessibilityIdentifier) else {
            return false
        }

        return self.viewIsVisible(view, visibility: visibility)
    }

    /// Returns if the specified view is visible.
    ///
    /// - parameter view:       The view to check.
    /// - parameter visibility: How determine if the view is visible.
    ///
    /// - returns: If the view is visible
    public func viewIsVisible(_ view: UIView, visibility: Visibility = .partial) -> Bool {
        guard view.isDescendant(of: self.window) else {
            return false
        }

        // Recursive
        func viewIsVisible(currentView: UIView) -> Bool {
            guard !currentView.isHidden && currentView.alpha >= 0.01 else {
                return false
            }

            guard let superview = currentView.superview else {
                return currentView == self.window
            }

            let adjustedBounds = view.convert(view.bounds, to: superview)
            guard superview.bounds.isVisible(adjustedBounds, visibility: visibility) else {
                return false
            }

            return viewIsVisible(currentView: superview)
        }

        return viewIsVisible(currentView: view)
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

    /// Returns if the specified view is hittable.
    ///
    /// NOTE: This will also return false if the view for the accessibility identifier is not found.
    ///
    /// - parameter accessibilityIdentifier: The identifier to check.
    /// - parameter point:                   A point to check if hittable in the view's coordinate space. If
    ///                                      nil, it will use the center of the view's visible area.
    ///
    /// - returns: If the view is hittable
    public func viewIsHittable(_ accessibilityIdentifier: String, atPoint point: CGPoint? = nil) -> Bool {
        guard let view = try? self.viewWithIdentifier(accessibilityIdentifier) else {
            return false
        }

        return self.viewIsHittable(view, atPoint: point)
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
        let windowHitTest = self.window.hitTest(windowHitPoint, with: nil)
        if windowHitTest == view {
            // If the hit test returns the target view we know it is hittable
            return true
        } else if windowHitTest == nil {
            // If the hit test returns nil there is no interactive view
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
        guard self.isWindowReady else {
            throw HammerError.windowIsNotReadyForInteraction
        }

        for point in points {
            if !self.pointIsHittable(point) {
                throw HammerError.pointIsNotHittable(point)
            }
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
        guard view.isDescendant(of: self.window) else {
            throw HammerError.viewIsNotInHierarchy(view)
        }

        guard self.isWindowReady else {
            throw HammerError.windowIsNotReadyForInteraction
        }

        guard self.viewIsVisible(view) else {
            throw HammerError.viewIsNotVisible(view)
        }

        guard self.viewIsHittable(view) else {
            throw HammerError.viewIsNotHittable(view)
        }

        return self.internalWindowHitPoint(forView: view)
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
