import UIKit

public enum FingerIndex: UInt32, CaseIterable {
    case rightThumb = 1
    case rightIndex = 2
    case rightMiddle = 3
    case rightRing = 4
    case rightLittle = 5

    case leftThumb = 6
    case leftIndex = 7
    case leftMiddle = 8
    case leftRing = 9
    case leftLittle = 10

    public static let automatic: FingerIndex? = nil

    static let defaultOrder = Array(FingerIndex.allCases.prefix(UIDevice.current.maxNumberOfFingers))
}

extension Array where Element == FingerIndex? {
    public static let automatic: [FingerIndex?] = []
}
