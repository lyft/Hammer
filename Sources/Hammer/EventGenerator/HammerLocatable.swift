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
