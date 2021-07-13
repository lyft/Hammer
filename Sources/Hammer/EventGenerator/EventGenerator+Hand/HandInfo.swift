import UIKit

struct HandInfo {
    let fingers: [FingerInfo]

    var isTouching: Bool {
        return self.fingers.contains(where: \.isTouching)
    }

    var eventMask: IOHID.DigitizerEventMask {
        // Only touch and attribute are applicable
        return self.fingers
            .map(\.eventMask)
            .reduce(IOHID.DigitizerEventMask()) { $0.union($1) }
            .intersection([.touch, .attribute])
    }
}

struct FingerInfo {
    let fingerIndex: FingerIndex
    let location: CGPoint
    let phase: UITouch.Phase

    let pressure: CGFloat
    let twist: CGFloat

    let majorRadius: CGFloat
    let minorRadius: CGFloat

    var eventMask: IOHID.DigitizerEventMask {
        return self.phase.eventMask.union(self.pressure > 0 ? .attribute : [])
    }

    var isTouching: Bool {
        return self.phase.isTouching
    }
}
