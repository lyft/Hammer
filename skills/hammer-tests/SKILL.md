---
name: hammer-tests
description: Write iOS unit tests that simulate real touches, swipes and typing with Hammer's EventGenerator, in XCTest or Swift Testing. Use when writing or fixing tests that tap buttons, scroll, type into fields or check UI behavior of UIKit or SwiftUI views with Hammer.
---

# Hammer tests

Hammer sends real touch and keyboard events to views in unit tests, so UIKit and SwiftUI handle them like a user's. Its API is async and runs on the main actor.

Only use the async API. Hammer also has synchronous versions of every method, for tests that are not async, but they are deprecated: never write `try eventGenerator.fingerTap()` without `await`, and convert synchronous tests you touch to async.

## Setup

- Tests need a host application, set on the test target. Without one, creating an event generator throws that the window is not ready.
- Mark XCTest classes `@MainActor` and make tests `async throws`.
- For Swift Testing, mark the suite `@MainActor` and `@Suite(.serialized)`, and call `finish()` at the end of each test since there is no tear down. Only the newest unfinished event generator can send events, so tests that use Hammer must not run in parallel.

```swift
@MainActor
final class SignInTests: XCTestCase {
    func testSignInButtonSubmits() async throws {
        let viewController = SignInViewController()
        let eventGenerator = try await EventGenerator(viewController: viewController)

        try await eventGenerator.fingerTap(at: "email_field")
        try await eventGenerator.keyType("me@example.com")
        try await eventGenerator.fingerTap(at: .label("Sign In", traits: .button))
        try await eventGenerator.waitUntil(viewController.didSubmit)
    }
}
```

Create the event generator from what you test: `EventGenerator(view:)` for a `UIView` or a SwiftUI view, `EventGenerator(viewController:)`, or `EventGenerator(window:)` for a key window. Views without a window are hosted in a temporary one, sized by their own constraints or frame, so give them a size.

## Finding elements

Pass the location to the event methods. Prefer, in order:

1. An accessibility identifier string: `fingerTap(at: "sign_in")`. It works for views and SwiftUI elements with `.accessibilityIdentifier(_:)`, so add identifiers to the code under test when they are missing.
2. An `AccessibilityQuery` for the label, value and traits: `.label("Continue", traits: .button)`, `AccessibilityQuery(label: "Wi-Fi", value: "1")`.
3. A view reference: `fingerTap(at: button)`.
4. A `CGPoint` in window coordinates, only when there is no element, such as a spot on a map.

When several elements match, Hammer prefers visible and actionable ones, and throws if it still can't choose. Make the query more specific instead of turning off `throwOnMultipleMatches`.

## Waiting

Never use `sleep` or fixed waits to let the UI settle. Wait for the state you need, which checks every frame:

```swift
try await eventGenerator.waitUntilHittable("checkout_button")
try await eventGenerator.waitUntilVisible(.label("Order placed"))
try await eventGenerator.waitUntilExists("results_list", timeout: 5)
try await eventGenerator.waitUntil(viewModel.isLoaded)
try await eventGenerator.waitUntilAnimationsAreFinished()
```

Event methods already wait for UIKit to process each event, so you only need to wait for what the app does in response, such as a navigation, a network stub or an animation.

## Gestures and keyboard

```swift
try await eventGenerator.fingerTap(at: "row")
try await eventGenerator.fingerDoubleTap(at: "image")
try await eventGenerator.fingerLongPress(at: "message", duration: 1)
try await eventGenerator.fingerSwipe(at: "list", direction: .up)  // Scrolls the content down
try await eventGenerator.fingerEdgeSwipe(direction: .right)        // Goes back in a navigation controller
try await eventGenerator.fingerDrag(from: "card", to: "trash", duration: 0.5)
try await eventGenerator.fingerPinchOpen(at: "map")
try await eventGenerator.keyType("Hello!")                         // Types into the first responder
try await eventGenerator.keyPress(.returnOrEnter)
```

Tap a text field before typing so it becomes first responder. When the typed text must match exactly, turn off the field's `autocorrectionType`, `spellCheckingType`, `smartQuotesType` and `smartDashesType` in the test.

## Pitfalls

- An element scrolled out of view is not visible, and tapping it throws. Swipe the scroll view until it is hittable first.
- Hammer can't reach system UI such as permission alerts, so stub the code that shows them.
- Errors like "not hittable" mean something covers the element or it ignores touches. Check for overlays, `isUserInteractionEnabled` and disabled controls before adding waits.
- Keep `EventGenerator.settings` changes in `setUp` and restore them in `tearDown`, or change `eventGenerator.settings` for one generator only.

To explore a screen of the running app first and find its identifiers and labels, use the `hammer-cli` skill.
