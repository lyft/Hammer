import Foundation
import Hammer
import HammerAgentCore

/// Explains an error to the client, with a hint on how to fix it so an agent can correct its next call.
struct ErrorReport {
    let status: Int
    let body: AgentErrorBody

    /// Creates the report for an error a command threw.
    ///
    /// - parameter error:      The error.
    /// - parameter descriptor: The command that threw it.
    init(_ error: Error, for descriptor: CommandDescriptor) {
        switch error {
        case let error as ArgumentsError:
            self.init(status: 400, code: .invalidArguments, error: error.description, hint: error.hint)
        case let error as AgentError:
            let status = if case .invalidArguments = error { 400 } else { 500 }
            self.init(status: status, code: error.code, error: error.description, hint: error.hint)
        case let error as DecodingError:
            self.init(status: 400, code: .invalidArguments, error: error.argumentsMessage,
                      hint: descriptor.argumentsHint)
        case HammerError.multipleElementsFound(let query, let count):
            // Hammer's own message suggests a test setting that agents can't change
            self.init(status: 500, code: .ambiguousTarget, error: "Found \(count) elements for \(query)",
                      hint: HammerError.multipleElementsFound(query: query, count: count).hint)
        case let error as HammerError:
            self.init(status: 500, code: error.code, error: error.description, hint: error.hint)
        default:
            self.init(status: 500, code: .failed, error: String(describing: error), hint: nil)
        }
    }

    private init(status: Int, code: AgentErrorCode, error: String, hint: String?) {
        self.status = status
        self.body = AgentErrorBody(error: error, code: code, hint: hint)
    }

    var response: HTTPResponse {
        return HTTPResponse(status: self.status, body: (try? JSONEncoder().encode(self.body)) ?? Data())
    }
}

extension HammerError {
    fileprivate var code: AgentErrorCode {
        switch self {
        case .unableToFindElement, .unableToFindView:
            return .notFound
        case .multipleElementsFound:
            return .ambiguousTarget
        case .elementIsNotVisible, .viewIsNotVisible, .viewIsNotInHierarchy:
            return .notVisible
        case .elementIsNotHittable, .viewIsNotHittable, .pointIsNotHittable:
            return .notHittable
        case .windowIsNotReadyForInteraction, .windowIsNotKey:
            return .notReady
        case .waitConditionTimeout, .eventProcessingTimeout:
            return .timedOut
        case .invalidViewType, .unknownKeyForCharacter:
            return .invalidArguments
        default:
            return .failed
        }
    }

    fileprivate var hint: String? {
        switch self {
        case .unableToFindElement, .unableToFindView:
            return """
                Call describe to see the elements on screen, or wait_for the element if it is still appearing
                """
        case .multipleElementsFound:
            return """
                Add more of identifier, label, value and traits to tell them apart, or pass a ref from \
                describe
                """
        case .elementIsNotVisible, .viewIsNotVisible:
            return "It is hidden or off screen: swipe to scroll it into view, or wait_for it to be visible"
        case .elementIsNotHittable, .viewIsNotHittable, .pointIsNotHittable:
            return """
                Something covers it or it ignores touches. Take a screenshot or call describe to see what is \
                on top, such as an alert, a sheet or the keyboard
                """
        case .viewIsNotInHierarchy:
            return "It is no longer on screen, call describe for the current elements"
        case .waitConditionTimeout:
            return """
                Take a screenshot to see the current state, then wait for a different element or pass a \
                longer timeout
                """
        case .windowIsNotReadyForInteraction, .eventProcessingTimeout:
            return "The app is busy or still presenting, call wait_for_idle and try again"
        case .windowIsNotKey:
            return "Another window has the keyboard focus, such as an alert. Dismiss it and try again"
        case .unknownKeyForCharacter:
            return "type_text types the characters of a US keyboard, use press_key with a key name for others"
        default:
            return nil
        }
    }
}

extension DecodingError {
    fileprivate var argumentsMessage: String {
        switch self {
        case .keyNotFound(let key, _):
            return "Missing argument \"\(key.stringValue)\""
        case .typeMismatch(_, let context), .valueNotFound(_, let context), .dataCorrupted(let context):
            let name = context.codingPath.map(\.stringValue).joined(separator: ".")
            return "Invalid argument \"\(name)\": \(context.debugDescription)"
        @unknown default:
            return String(describing: self)
        }
    }
}
