# Getting started

Hammer is a touch, stylus and keyboard synthesis library for emulating user interaction events. It enables better ways of triggering UI actions in unit tests, replicating a real world environment as much as possible.

⚠️ IMPORTANT: This library makes extensive use of private APIs and should never be included in a production app.

## Installation

Hammer requires Swift 6.0 and iOS 17.0 or later.

### With [SwiftPM](https://swift.org/package-manager)

```swift
.package(url: "https://github.com/lyft/Hammer.git", from: "2.0.0")
```

Add the `Hammer` product to your test target.

### With [CocoaPods](https://cocoapods.org/) (deprecated)

CocoaPods support is deprecated and will not be updated. Versions up to 0.15.0 remain available on CocoaPods trunk, but newer releases are only available through SwiftPM.

```ruby
pod 'HammerTests', '~> 0.15.0'
```

## Host application

Hammer unit tests need to run in a host application to be able to generate touches. To configure this select your project in the sidebar, select your test target, and choose a host application in the general tab. The host application can be your main application or an empty wrapper like [TestHost](../../TestHost).

SwiftPM does not currently support creating applications. To use Hammer with SwiftPM frameworks you need to create an xcodeproj and setup a host application.

## Your first test

Hammer runs on the main actor and its API is async, so tests that use it should be async and isolated to the main actor:

```swift
@MainActor
final class MyViewTests: XCTestCase {
    func testButtonTap() async throws {
        let eventGenerator = try await EventGenerator(view: myView)
        try await eventGenerator.fingerTap(at: "my_button")
    }
}
```

To be able to send events to a view you must first create an `EventGenerator`:

```swift
// Initialize for an existing UIWindow, ensure that the window is key and visible.
let eventGenerator = try await EventGenerator(window: myWindow)

// Initialize for a UIView, automatically wrapping it in a temporary window.
let eventGenerator = try await EventGenerator(view: myView)

// Initialize for a UIViewController, automatically wrapping it in a temporary window.
let eventGenerator = try await EventGenerator(viewController: myViewController)

// Initialize for a SwiftUI view, automatically hosting it in a temporary window.
let eventGenerator = try await EventGenerator(view: MySwiftUIView())
```

Views without a window are hosted in a temporary one, sized by their own constraints or frame, so give them a size.

By default, Hammer will display simulated touches over the view. You can change this behavior for your event generator.

```swift
eventGenerator.showTouches = false
```

## Next steps

- [Touches](touches.md): fingers, gestures and stylus.
- [Keyboard](keyboard.md): typing and key presses.
- [Finding views](finding-views.md): targeting views and SwiftUI elements.
- [Waiting](waiting.md): waiting for the app, finishing and settings.
- [Swift Testing](swift-testing.md): using Hammer outside XCTest.
