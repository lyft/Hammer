import CoreGraphics
import Foundation

extension CGPoint {
    /// Calculates the offset point by translating using the specified x and y values.
    ///
    /// - parameter x: The offset in the horizontal direction, positive means to the right.
    /// - parameter y: The offset in the vertical direction, positive means down.
    ///
    /// - returns: The offset point.
    func offset(x: CGFloat, y: CGFloat) -> CGPoint {
        return CGPoint(x: self.x + x, y: self.y + y)
    }

    /// Calculates the offset point by moving a specified distance along an angle. A zero angle is assumed
    /// to be straight to the right.
    ///
    /// - parameter distance: The distance to move in the angle.
    /// - parameter radians:  The angle to move in, 0 means straight to the right.
    ///
    /// - returns: The offset point.
    func offset(_ distance: CGFloat, angle radians: CGFloat) -> CGPoint {
        return self.offset(x: distance * cos(radians), y: distance * sin(radians))
    }

    /// Calculates the offset point by moving a specified distance at an angle. The distance will be split
    /// between both directions. A zero angle is assumed to be straight to the right.
    ///
    /// - parameter distance: The distance to move in the angle
    /// - parameter radians:  The angle to move in, 0 means straight to the right.
    ///
    /// - returns: The offset point.
    func twoWayOffset(_ distance: CGFloat, angle radians: CGFloat) -> [CGPoint] {
        return [
            self.offset(distance / 2, angle: radians),
            self.offset(distance / 2, angle: .pi + radians),
        ]
    }

    /// Calculates a new point by pivoting around an anchor by a specified angle.
    ///
    /// - parameter anchor:  The point to pivot around.
    /// - parameter radians: The angle to rotate.
    ///
    /// - returns: The offset point.
    func pivot(anchor: CGPoint, angle radians: CGFloat) -> CGPoint {
        return CGPoint(x: anchor.x + (self.x - anchor.x) * cos(radians) - (self.y - anchor.y) * sin(radians),
                       y: anchor.y + (self.x - anchor.x) * sin(radians) + (self.y - anchor.y) * cos(radians))
    }
}

extension CGRect {
    /// Convenience getter for the center of a rect.
    var center: CGPoint {
        return CGPoint(x: self.midX, y: self.midY)
    }

    /// Returns if the specified rect is visible.
    ///
    /// - parameter rect:       The rect to check in self coordinate space.
    /// - parameter visibility: How determine if the rect is visible.
    ///
    /// - returns: If the rect is visible
    func isVisible(_ rect: CGRect, visibility: EventGenerator.Visibility = .partial) -> Bool {
        switch visibility {
        case .partial:
            return self.intersects(rect)
        case .center:
            return self.contains(rect.center)
        case .full:
            return self.contains(rect)
        }
    }
}

func curveInterpolation(from start: CGFloat, to end: CGFloat, time: TimeInterval) -> CGFloat {
    return start + (end - start) * CGFloat(sin(sin(time * .pi / 2) * time * .pi / 2))
}

func curveInterpolation(from start: CGPoint, to end: CGPoint, time: TimeInterval) -> CGPoint {
    return CGPoint(x: curveInterpolation(from: start.x, to: end.x, time: time),
                   y: curveInterpolation(from: start.y, to: end.y, time: time))
}
