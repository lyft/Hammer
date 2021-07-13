import UIKit

public enum HammerError: Error {
    case windowIsNotReadyForInteraction

    case deviceDoesNotSupportTouches
    case deviceDoesNotSupportStylus

    case touchForFingerAlreadyExists(index: FingerIndex)
    case touchForFingerDoesNotExist(index: FingerIndex)
    case fingerLimitReached(limit: Int)
    case ranOutOfFingersForTouchUp
    case invalidFingerCount(count: Int, expected: Int)

    case touchForStylusAlreadyExists
    case touchForStylusDoesNotExist

    case unknownKeyForCharacter(Character)

    case unsupportedTouchPhase(UITouch.Phase)

    case unableToAccessPrivateApi(type: String, method: String)

    case viewIsNotInHierarchy
    case viewIsNotVisible
    case viewIsNotHittable
    case pointIsNotHittable(point: CGPoint)

    case unableToFindView(identifier: String)
    case invalidViewType(identifier: String)
    case waitConditionTimeout
}
