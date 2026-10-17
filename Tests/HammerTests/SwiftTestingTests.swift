import Hammer
import Testing
import UIKit

@MainActor
@Suite(.serialized)
struct SwiftTestingTests {
    @Test
    func buttonTap() async throws {
        var tapCount = 0
        let view = UIButton(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        view.addHandler(forEvent: .primaryActionTriggered) { tapCount += 1 }

        let eventGenerator = try await EventGenerator(view: view)
        try await eventGenerator.waitUntilHittable()
        try await eventGenerator.fingerTap()
        try await eventGenerator.finish()

        #expect(tapCount == 1)
    }

    @Test
    func typeOnTextField() async throws {
        let view = UITextField()
        view.setSize(width: 300)
        view.disableTextSuggestions()
        view.autocapitalizationType = .none

        let eventGenerator = try await EventGenerator(view: view)
        try await eventGenerator.fingerTap()
        try await eventGenerator.keyType("abc")
        try await eventGenerator.finish()

        #expect(view.text == "abc")
    }

    @Test
    func waitUntilThrowsOnTimeout() async throws {
        let eventGenerator = try await EventGenerator(view: UIView().withSize(width: 100, height: 100))
        eventGenerator.settings.waitTimeout = 0.1
        await #expect(throws: HammerError.self) {
            try await eventGenerator.waitUntil(false)
        }

        try await eventGenerator.finish()
    }
}
