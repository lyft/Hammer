import CoreGraphics

/// The direction a finger moves during a swipe.
public enum SwipeDirection: CaseIterable {
    case up
    case down
    case left
    case right

    /// The unit vector of the direction, in window coordinates.
    var vector: CGVector {
        switch self {
        case .up:
            return CGVector(dx: 0, dy: -1)
        case .down:
            return CGVector(dx: 0, dy: 1)
        case .left:
            return CGVector(dx: -1, dy: 0)
        case .right:
            return CGVector(dx: 1, dy: 0)
        }
    }
}
