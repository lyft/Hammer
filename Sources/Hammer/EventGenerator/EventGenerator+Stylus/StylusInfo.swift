import Foundation
import UIKit

struct StylusInfo {
    let location: CGPoint
    let phase: UITouch.Phase

    let pressure: CGFloat
    let twist: CGFloat

    let altitude: CGFloat
    let azimuth: CGFloat

    var eventMask: IOHID.DigitizerEventMask {
        return self.phase.eventMask.union(.attribute)
    }
}
