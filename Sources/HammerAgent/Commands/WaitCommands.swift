import Foundation
import Hammer
import HammerAgentCore
import UIKit

private let kDefaultTimeout: TimeInterval = 10

struct WaitForCommand: AgentCommand {
    enum Condition: String, Decodable {
        case exists
        case visible
        case hittable
        case gone

        /// The state the element did not reach, to explain a timeout.
        var expectedState: String {
            return self == .exists ? "found" : self.rawValue
        }
    }

    struct Arguments: Decodable {
        private enum CodingKeys: String, CodingKey {
            case condition
            case timeout
        }

        let target: Target
        let condition: Condition
        let timeout: TimeInterval

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.target = try Target(from: decoder)
            self.condition = try container.decodeIfPresent(Condition.self, forKey: .condition) ?? .hittable
            self.timeout = try container.decodeIfPresent(TimeInterval.self, forKey: .timeout)
                ?? kDefaultTimeout
        }
    }

    let descriptor = BuiltinCommands.waitFor

    func run(_ arguments: Arguments, in context: AgentContext) async throws -> NoOutput {
        let query = try arguments.target.requiredQuery()
        let eventGenerator = try await context.eventGenerator()
        let deadline = Date().addingTimeInterval(arguments.timeout)
        var web = WebMatches()
        while true {
            if Self.isMet(arguments.condition, for: query, in: eventGenerator, web: web) {
                return NoOutput()
            }

            guard Date() < deadline else {
                break
            }

            // Views are checked every frame, and pages less often, since reading one takes longer
            if web.isDue {
                await web.read(query, in: eventGenerator.window, until: deadline)
            } else {
                try await eventGenerator.wait(kPollInterval)
            }
        }

        let state = if eventGenerator.elementExists(query) || !web.elements.isEmpty {
            "it exists"
        } else if web.hadUnreadablePage {
            "a web page couldn't be read, so it may still exist there"
        } else {
            "it does not exist"
        }

        throw AgentError.failed("""
            The element with \(query) was not \(arguments.condition.expectedState) after \
            \(arguments.timeout) seconds, and \(state)
            """, hint: """
            Take a screenshot or call describe to see the current state, then wait for a different \
            element or pass a longer timeout
            """, code: .timedOut)
    }

    /// Checks the condition for the views and accessibility elements, then for the elements of web pages
    /// from their last read.
    private static func isMet(_ condition: Condition, for query: AccessibilityQuery,
                              in eventGenerator: EventGenerator, web: WebMatches) -> Bool
    {
        switch condition {
        case .exists:
            return eventGenerator.elementExists(query) || !web.elements.isEmpty
        case .visible:
            return eventGenerator.elementIsVisible(query) || web.elements.contains(where: \.isVisible)
        case .hittable:
            return eventGenerator.elementIsHittable(query) || web.elements.contains(where: \.isHittable)
        case .gone:
            // A page that couldn't be read may still have the element
            return !eventGenerator.elementExists(query) && web.isRead && web.elements.isEmpty
                && !web.hadUnreadablePage
        }
    }
}

/// The elements of the window's web pages that match a wait's query, read again every `kWebPollInterval`.
@MainActor
private struct WebMatches {
    /// The matches from the last read.
    private(set) var elements = [WebContent.Element]()

    /// If a read ran, or the window had no web views to read.
    private(set) var isRead = false

    /// If a page couldn't be read in the last read.
    private(set) var hadUnreadablePage = false

    private var lastRead: Date?

    /// If it's time to read the pages again.
    var isDue: Bool {
        return self.lastRead.map { Date().timeIntervalSince($0) >= kWebPollInterval } ?? true
    }

    mutating func read(_ query: AccessibilityQuery, in window: UIWindow, until deadline: Date) async {
        self.lastRead = Date()
        // A short timeout, so a page that doesn't answer holds up the checks of the views only briefly
        let timeout = min(kWebReadTimeout, max(deadline.timeIntervalSinceNow, 0.1))
        let matches = await WebContent.elements(matching: query, in: window, timeout: timeout)
        self.elements = matches.elements
        self.hadUnreadablePage = matches.hadUnreadablePage
        self.isRead = true
    }
}

/// How often waits check views, about every frame.
private let kPollInterval: TimeInterval = 1.0 / 60

/// How often waits read web pages, less often than views since a read takes a call to the web content
/// process.
private let kWebPollInterval: TimeInterval = 0.15

struct WaitForIdleCommand: AgentCommand {
    struct Arguments: Decodable {
        var timeout: TimeInterval?
    }

    let descriptor = BuiltinCommands.waitForIdle

    func run(_ arguments: Arguments, in context: AgentContext) async throws -> NoOutput {
        try await context.eventGenerator()
            .waitUntilAnimationsAreFinished(timeout: arguments.timeout ?? kDefaultTimeout)
        return NoOutput()
    }
}

/// How long a wait gives a web view to answer each read.
private let kWebReadTimeout: TimeInterval = 1
