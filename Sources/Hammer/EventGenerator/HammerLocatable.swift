import UIKit

public protocol HammerLocatable {
    func screenHitPoint(for eventGenerator: EventGenerator) throws -> CGPoint
}

extension CGPoint: HammerLocatable {
    public func screenHitPoint(for eventGenerator: EventGenerator) throws -> CGPoint {
        return self
    }
}

extension CGRect: HammerLocatable {
    public func screenHitPoint(for eventGenerator: EventGenerator) throws -> CGPoint {
        return self.center
    }
}

extension UIView: HammerLocatable {
    public func screenHitPoint(for eventGenerator: EventGenerator) throws -> CGPoint {
        return try eventGenerator.screenHitPoint(forView: self)
    }
}

extension UIViewController: HammerLocatable {
    public func screenHitPoint(for eventGenerator: EventGenerator) throws -> CGPoint {
        return try self.view.screenHitPoint(for: eventGenerator)
    }
}

extension String: HammerLocatable {
    public func screenHitPoint(for eventGenerator: EventGenerator) throws -> CGPoint {
        return try eventGenerator.viewWithIdentifier(self).screenHitPoint(for: eventGenerator)
    }
}
