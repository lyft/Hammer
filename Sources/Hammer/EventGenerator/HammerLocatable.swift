import UIKit

public protocol HammerLocatable {
    func windowHitPoint(for eventGenerator: EventGenerator) throws -> CGPoint
}

extension CGPoint: HammerLocatable {
    public func windowHitPoint(for eventGenerator: EventGenerator) throws -> CGPoint {
        return self
    }
}

extension CGRect: HammerLocatable {
    public func windowHitPoint(for eventGenerator: EventGenerator) throws -> CGPoint {
        return self.center
    }
}

extension UIView: HammerLocatable {
    public func windowHitPoint(for eventGenerator: EventGenerator) throws -> CGPoint {
        return try eventGenerator.windowHitPoint(forView: self)
    }
}

extension UIViewController: HammerLocatable {
    public func windowHitPoint(for eventGenerator: EventGenerator) throws -> CGPoint {
        return try self.view.windowHitPoint(for: eventGenerator)
    }
}

extension String: HammerLocatable {
    public func windowHitPoint(for eventGenerator: EventGenerator) throws -> CGPoint {
        return try eventGenerator.viewWithIdentifier(self).windowHitPoint(for: eventGenerator)
    }
}

/// Creates an absolute offset for a location in screen points.
public struct OffsetLocation: HammerLocatable {
    public let location: HammerLocatable?
    public let x: CGFloat
    public let y: CGFloat

    /// Creates an offset for a location.
    ///
    /// - parameter location: The location to offset. Passing nil will use the default location.
    /// - parameter x:        The x offset.
    /// - parameter y:        The y offset.
    public init(location: HammerLocatable? = nil, x: CGFloat, y: CGFloat) {
        self.location = location
        self.x = x
        self.y = y
    }

    public func windowHitPoint(for eventGenerator: EventGenerator) throws -> CGPoint {
        let location = self.location ?? eventGenerator.mainView
        let hitPoint = try location.windowHitPoint(for: eventGenerator)
        return CGPoint(x: hitPoint.x + self.x,
                       y: hitPoint.y + self.y)
    }
}

/// Creates a relative location for a view.
public struct RelativeLocation: HammerLocatable {
    public let view: UIView?
    public let x: CGFloat
    public let y: CGFloat

    /// Creates a relative location for a view
    ///
    /// Values for x and y are relative to the dimensions of the view. From 0 to 1, 0 being the top/left of
    /// the view and 1 being the bottom/right of the view. Passing a value outside those bounds will result
    /// in the touch occurring outside the view.
    ///
    /// - parameter view: The view to get a relative location for. Passing nil will use the default view.
    /// - parameter x:    The relative x value.
    /// - parameter y:    The relative y value.
    public init(location view: UIView? = nil, x: CGFloat, y: CGFloat) {
        self.view = view
        self.x = x
        self.y = y
    }

    public func windowHitPoint(for eventGenerator: EventGenerator) throws -> CGPoint {
        let view = self.view ?? eventGenerator.mainView
        let hitPoint = try eventGenerator.windowHitPoint(forView: view)
        return CGPoint(x: hitPoint.x - view.bounds.center.x + view.bounds.width * self.x,
                       y: hitPoint.y - view.bounds.center.y + view.bounds.height * self.y)
    }
}
