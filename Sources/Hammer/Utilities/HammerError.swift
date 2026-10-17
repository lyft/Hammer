import UIKit

/// https://github.com/lyft/Hammer#troubleshooting.
public enum HammerError: Error, @unchecked Sendable {
    case windowIsNotReadyForInteraction(reason: WindowNotReadyReason)
    case windowIsNotKey
    case eventProcessingTimeout(TimeInterval)
    case eventGeneratorIsFinished
    case anotherEventGeneratorIsActive

    case deviceDoesNotSupportTouches
    case deviceDoesNotSupportStylus

    case touchForFingerAlreadyExists(index: FingerIndex)
    case touchForFingerDoesNotExist(index: FingerIndex)
    case fingerLimitReached(limit: Int)
    case invalidFingerCount(count: Int, expected: Int)
    case touchWasNotDelivered(index: FingerIndex)

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

    case waiterIsNotRunning
    case waiterIsAlreadyRunning
    case waiterIsAlreadyCompleted
}

extension HammerError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .windowIsNotReadyForInteraction(let reason):
            return """
                The app or window is not ready for interaction: \(reason). Ensure that your tests are \
                running in a host application and that you have given enough time for the view to present \
                on screen. For more troubleshooting tips see: https://github.com/lyft/Hammer#troubleshooting.
                """
        case .windowIsNotKey:
            return "The window must be the key window to receive keyboard events"
        case .eventProcessingTimeout(let timeout):
            return "UIKit did not process the generated event within \(timeout) seconds"
        case .eventGeneratorIsFinished:
            return "The event generator is finished and cannot send more events"
        case .anotherEventGeneratorIsActive:
            return """
                An event generator created after this one is still active. Finish or release it before \
                sending events with this one, and run tests that use Hammer serially.
                """
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
        case .touchWasNotDelivered(let index):
            return "The touch for finger with index \(index) was not delivered to the app"
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
            return "View is not visible: \(view.shortDescription)"
        case .viewIsNotHittable(let view):
            return "View is not hittable: \(view.shortDescription)"
        case .pointIsNotHittable(let point):
            return "Point is not hittable: \(point)"
        case .unableToFindView(let identifier):
            return "Unable to find view: \"\(identifier)\""
        case .invalidViewType(let identifier, let type, let expected):
            return "Invalid type for view: \"\(identifier)\", got \"\(type)\" expected \"\(expected)\""
        case .waitConditionTimeout(let timeout):
            return "Timeout while waiting for condition exceeded \(timeout) seconds"
        case .waiterIsNotRunning:
            return "Unable to stop a Waiter that is not running"
        case .waiterIsAlreadyRunning:
            return "Unable to start a Waiter that is already running"
        case .waiterIsAlreadyCompleted:
            return "Unable to start or stop a waiter that is already completed"
        }
    }
}

extension UIView {
    // Errors can be described from any thread, but the view can only be read on the main thread
    nonisolated fileprivate var shortDescription: String {
        guard Thread.isMainThread else {
            return String(describing: type(of: self))
        }

        return MainActor.assumeIsolated { self.accessibilityIdentifier ?? self.description }
    }
}
