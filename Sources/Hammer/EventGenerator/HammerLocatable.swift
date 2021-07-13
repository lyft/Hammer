import UIKit

public protocol HammerLocatable {
    func hitPoint(for eventGenerator: EventGenerator) throws -> CGPoint
}

extension CGPoint: HammerLocatable {
    public func hitPoint(for eventGenerator: EventGenerator) throws -> CGPoint {
        return self
    }
}

extension CGRect: HammerLocatable {
    public func hitPoint(for eventGenerator: EventGenerator) throws -> CGPoint {
        return self.center
    }
}

extension UIView: HammerLocatable {
    public func hitPoint(for eventGenerator: EventGenerator) throws -> CGPoint {
        return try eventGenerator.hitPoint(forView: self)
    }
}

extension UIViewController: HammerLocatable {
    public func hitPoint(for eventGenerator: EventGenerator) throws -> CGPoint {
        return try self.view.hitPoint(for: eventGenerator)
    }
}

extension String: HammerLocatable {
    public func hitPoint(for eventGenerator: EventGenerator) throws -> CGPoint {
        return try eventGenerator.viewWithIdentifier(self).hitPoint(for: eventGenerator)
    }
}
