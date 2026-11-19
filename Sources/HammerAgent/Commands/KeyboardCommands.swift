import Foundation
import Hammer
import HammerAgentCore

struct TypeTextCommand: AgentCommand {
    struct Arguments: Decodable {
        private enum CodingKeys: String, CodingKey {
            case text
        }

        let text: String
        let target: Target

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.text = try container.decode(String.self, forKey: .text)
            self.target = try Target(from: decoder)
        }
    }

    let descriptor = BuiltinCommands.typeText

    func run(_ arguments: Arguments, in context: AgentContext) async throws -> NoOutput {
        let eventGenerator = try await context.eventGenerator()
        switch try await arguments.target.resolve(in: context) {
        case .location(let location?):
            try await eventGenerator.fingerTap(at: location)
        case .location(nil):
            break
        case .webElement(let element):
            try await eventGenerator.fingerTap(at: try element.checkedHitPoint())
            if element.isEditable {
                try await self.waitForFocus(on: element, eventGenerator: eventGenerator)
            }
        }

        try await eventGenerator.keyType(arguments.text)
        return NoOutput()
    }

    /// Waits for a web page's field to take the focus after a tap, since the page takes it apart from the
    /// app, so the text doesn't go to the field that had it before.
    private func waitForFocus(on element: WebContent.Element, eventGenerator: EventGenerator) async throws {
        let deadline = Date().addingTimeInterval(kWebFocusTimeout)
        while true {
            let focus = await WebContent.focus(of: element)
            if focus == .focused {
                return
            }

            guard Date() < deadline else {
                let reason = switch focus {
                case .notInPage(let active?): "the page gave the focus to \(active) instead"
                case .notInPage(nil): "the page did not give it the focus"
                case .focused, .notInApp:
                    "the page gave it the focus, but the web view isn't the app's first responder"
                }

                throw AgentError.failed("\(element.summary) didn't take the focus after the tap: \(reason)",
                                        hint: """
                    Take a screenshot to see if something covers it, or tap it and type without a target
                    """, code: .timedOut)
            }

            try await eventGenerator.wait(0.05)
        }
    }
}

private let kWebFocusTimeout: TimeInterval = 3

struct PressKeyCommand: AgentCommand {
    struct Arguments: Decodable {
        let key: String
    }

    let descriptor = BuiltinCommands.pressKey

    func run(_ arguments: Arguments, in context: AgentContext) async throws -> NoOutput {
        let eventGenerator = try await context.eventGenerator()
        if let key = KeyboardKey.allCases.first(where: { "\($0)" == arguments.key }) {
            try await eventGenerator.keyPress(key)
        } else if arguments.key.count == 1, let character = arguments.key.first {
            try await eventGenerator.keyPress(character)
        } else {
            let names = KeyboardKey.allCases.map { "\($0)" }
            let suggestion = closestMatch(to: arguments.key, in: names)
                .map { ", did you mean \($0)?" } ?? ""
            throw AgentError.invalidArguments("Unknown key \"\(arguments.key)\"\(suggestion)", hint: """
                Pass a single character or a key name, such as returnOrEnter, escape, deleteOrBackspace, \
                tab, spacebar, arrowUp, arrowDown, arrowLeft or arrowRight
                """)
        }

        return NoOutput()
    }
}
