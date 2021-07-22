import UIKit

extension UITouch.Phase {
    // Returns 1 for all events where the fingers are on the glass.
    var isTouching: Bool {
        return self == .began || self == .moved || self == .stationary
    }

    var eventMask: IOHID.DigitizerEventMask {
        var mask: IOHID.DigitizerEventMask = []

        if self == .began || self == .ended || self == .cancelled {
            mask.insert(.touch)
            mask.insert(.range)
        }

        if self == .moved {
            mask.insert(.position)
        }

        if self == .cancelled {
            mask.insert(.cancel)
        }

        return mask
    }
}

extension UIDevice {
    public var maxNumberOfFingers: Int {
        switch self.userInterfaceIdiom {
        case .phone, .carPlay:
            return 5
        case .pad:
            return 10
        default:
            return 0
        }
    }

    public var supportsStylus: Bool {
        return self.userInterfaceIdiom == .pad
    }
}
