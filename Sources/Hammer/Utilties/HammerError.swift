import UIKit

/// https://github.com/lyft/Hammer#troubleshooting.
public enum HammerError: Error {
    case windowIsNotReadyForInteraction
    case windowIsNotKey

    case deviceDoesNotSupportTouches
    case deviceDoesNotSupportStylus

    case touchForFingerAlreadyExists(index: FingerIndex)
    case touchForFingerDoesNotExist(index: FingerIndex)
    case fingerLimitReached(limit: Int)
    case invalidFingerCount(count: Int, expected: Int)

    case touchForStylusAlreadyExists
    case touchForStylusDoesNotExist

    case unknownKeyForCharacter(Character)

    case unsupportedTouchPhase(UITouch.Phase)

    case unableToAccessPrivateApi(type: String, method: String)

    case viewIsNotInHierarchy(UIView)
    case viewIsNotVisible(UIView)
    case viewIsNotHittable(UIView)
    case pointIsNotHittable(CGPoint)

    case unableToFindView(identifier: String)
    case invalidViewType(identifier: String, type: String, expected: String)
    case waitConditionTimeout(TimeInterval)
}

extension HammerError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .windowIsNotReadyForInteraction:
            return """
                The app or window is not ready for interaction. Ensure that your tests are running in a \
                host application and that you have given enough time for the view to present on screen. \
                For more troubleshooting tips see: https://github.com/lyft/Hammer#troubleshooting.
                """
        case .windowIsNotKey:
            return "The window must be the key window to receive keyboard events"
        case .deviceDoesNotSupportTouches:
            return "Device does not support touches"
        case .deviceDoesNotSupportStylus:
            return "Device does not support stylus"
        case .touchForFingerAlreadyExists(let index):
            return "A touch for finger with index \(index) already exists"
        case .touchForFingerDoesNotExist(let index):
            return "A touch for finger with index \(index) does not exist"
        case .fingerLimitReached(let limit):
            return "The maximum number of fingers on the screen simultaneously has been exceeded (\(limit))"
        case .invalidFingerCount(let count, let expected):
            return "Invalid number of fingers, got \(count) expected \(expected)"
        case .touchForStylusAlreadyExists:
            return "A touch for the stylus already exists"
        case .touchForStylusDoesNotExist:
            return "A touch for the stylus does not exists"
        case .unknownKeyForCharacter(let character):
            return "Unknown keyboard mapping for character: \"\(character)\""
        case .unsupportedTouchPhase(let phase):
            return "Unsupported touch phase \(phase)"
        case .unableToAccessPrivateApi(let type, let method):
            return "Unable to access private API in \(type): \"\(method)\""
        case .viewIsNotInHierarchy(let view):
            return "View is not in hierarchy: \(view.shortDescription)"
        case .viewIsNotVisible(let view):
            return "View is not in visible: \(view.shortDescription)"
        case .viewIsNotHittable(let view):
            return "View is not in hittable: \(view.shortDescription)"
        case .pointIsNotHittable(let point):
            return "Point is not in hittable: \(point)"
        case .unableToFindView(let identifier):
            return "Unable to find view: \"\(identifier)\""
        case .invalidViewType(let identifier, let type, let expected):
            return "Invalid type for view: \"\(identifier)\", got \"\(type)\" expected \"\(expected)\""
        case .waitConditionTimeout(let timeout):
            return "Timeout while waiting for condition exceeded \(timeout) seconds"
        }
    }
}

extension UIView {
    fileprivate var shortDescription: String {
        return self.accessibilityIdentifier ?? self.description
    }
}
