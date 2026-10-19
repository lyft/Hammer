<p align="center"><img src="https://user-images.githubusercontent.com/585835/116218212-273b4880-a6ff-11eb-93ec-7c28d821f620.png" alt="" width="80" height="80"></p>
<h1 align="center">Hammer</h1>
<p align="center">If you can't touch this, it's Hammer time!</p>

<p align="center"><img src="https://user-images.githubusercontent.com/585835/116217617-ab410080-a6fe-11eb-9de1-3d42f7dd6037.gif" alt="Demo"></p>

<details open="open">
  <summary>Table of Contents</summary>
  <ol>
    <li><a href="#introduction">Introduction</a></li>
    <li><a href="#installation">Installation</a></li>
    <li><a href="#setup">Setup</a></li>
    <li><a href="#usage">Usage</a><ul>
      <li><a href="#simulating-fingers">Simulating Fingers</a></li>
      <li><a href="#simulating-stylus">Simulating Stylus</a></li>
      <li><a href="#simulating-keyboard">Simulating Keyboard</a></li>
      <li><a href="#finding-a-subview">Finding a Subview</a></li>
      <li><a href="#waiting">Waiting</a></li>
      <li><a href="#finishing">Finishing</a></li>
      <li><a href="#settings">Settings</a></li>
      <li><a href="#swift-testing">Swift Testing</a></li>
      <li><a href="#synchronous-tests">Synchronous Tests</a></li>
      <li><a href="#upgrading-from-1x">Upgrading from 1.x</a></li>
    </ul></li>
    <li><a href="#troubleshooting">Troubleshooting</a></li>
    <li><a href="#license">License</a></li>
  </ol>
</details>

## Introduction

Hammer is a touch, stylus and keyboard synthesis library for emulating user interaction events. It enables better ways of triggering UI actions in unit tests, replicating a real world environment as much as possible.

⚠️ IMPORTANT: This library makes extensive use of private APIs and should never be included in a production app.

## Installation

#### Requirements

Hammer requires Swift 6.0 and iOS 17.0 or later.

#### With [SwiftPM](https://swift.org/package-manager)

```swift
.package(url: "https://github.com/lyft/Hammer.git", from: "2.0.0")
```

#### With [CocoaPods](https://cocoapods.org/) (deprecated)

CocoaPods support is deprecated and will not be updated. Versions up to 0.15.0 remain available on CocoaPods trunk, but newer releases are only available through SwiftPM.

```ruby
pod 'HammerTests', '~> 0.15.0'
```

## Setup

Hammer unit tests need to run in a host application to be able to generate touches. To configure this select your project in the sidebar, select your test target, and choose a host application in the general tab. The host application can be your main application or an empty wrapper like [TestHost](./TestHost).

SwiftPM does not currently support creating applications. To use Hammer with SwiftPM frameworks you need to create an xcodeproj and setup a host application.

## Usage

Hammer allows you to simulate fingers, stylus and keyboard events. It also provides various convenience methods to simulate higher level user interactions.

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

When simulating finger or stylus touches, there are multiple ways of specifying a touch location:

1. Default: If you don't specify a location it will use the center of the screen.
2. Point: A CGPoint in screen coordinates.
3. View: A reference to a UIView or UIViewController, the location will be the center of the visible part of the view.
4. Identifier: An accessibility identifier string of a view or SwiftUI element, the location will be the center of the visible part of the view, or the activation point of the SwiftUI element.

By default, Hammer will display simulated touches over the view. You can change this behavior for your event generator.

```swift
eventGenerator.showTouches = false
```

### Simulating Fingers

Fingers are the most common method of user interaction on iOS. Hammer supports handling multiple fingers on the screen simultaneously, up to the limit on the device. You can specify the specific finger index you would like to use, if unspecified it will choose the most appropriate one automatically.

Primitive events are the basic building blocks of user interactions, they can be combined together to create full gestures. Some methods will allow you to specify a duration and will interpolate the changes during that time.

```swift
try await eventGenerator.fingerDown(at: CGPoint(x: 10, y: 10))
try await eventGenerator.fingerMove(to: CGPoint(x: 20, y: 10), duration: 0.5)
try await eventGenerator.fingerUp()
```

For convenience, Hammer provides many higher level gestures. If you don't specify a location it will automatically default to the center of the view.

```swift
try await eventGenerator.fingerTap()
try await eventGenerator.fingerDoubleTap()
try await eventGenerator.fingerLongPress()
try await eventGenerator.twoFingerTap()
```

Many advanced gestures are also available.

```swift
try await eventGenerator.fingerDrag(from: CGPoint(x: 10, y: 10), to: CGPoint(x: 20, y: 10), duration: 0.5)
try await eventGenerator.fingerPinch(fromDistance: 100, toDistance: 50, duration: 0.5)
try await eventGenerator.fingerRotate(angle: .pi, duration: 0.5)
```

### Simulating Stylus

Stylus is available when running on an iPad. It allows for additional properties like pressure, altitude and azimuth to be specified.

Similar to fingers, primitive events are the basic building blocks of stylus interactions.

```swift
try await eventGenerator.stylusDown(at: CGPoint(x: 10, y: 10), azimuth: 0, altitude: 0, pressure: 0.5)
try await eventGenerator.stylusMove(to: CGPoint(x: 20, y: 10), duration: 0.5)
try await eventGenerator.stylusUp()
```

Hammer also provides many higher level gestures for Stylus. If you don't specify a location it will automatically default to the center of the view.

```swift
try await eventGenerator.stylusTap()
try await eventGenerator.stylusDoubleTap()
try await eventGenerator.stylusLongPress()
```

### Simulating Keyboard

Keyboard methods take an explicit `KeyboardKey` object or a `Character`. Characters will be mapped to their closest keyboard key, you must wrap them with a shift key modifier if needed. This means that specifying a lowercase "a" character is equivalent to specifying an uppercase "A", this is also true for keys with symbols.

```swift
// Explicit `KeyboardKey`
try await eventGenerator.keyDown(.letterA)
try await eventGenerator.keyUp(.letterA)

// Automatic `Character` mapping
try await eventGenerator.keyDown("a")
try await eventGenerator.keyUp("a")

// Convenience key down and up events
try await eventGenerator.keyPress(.letterA)
try await eventGenerator.keyPress("a")
```

To type characters or longer strings and get automatic shift wrapping you can use the `keyType()` methods.

```swift
try await eventGenerator.keyType("This will type the string as specified, including symbols!")
```

### Finding a subview

When running on a full screen app or testing navigation, specifying a CGPoint in screen coordinates can be difficult. For this, Hammer provides convenience methods to find views in the hierarchy by their accessibility identifier.

```swift
let myButton = try eventGenerator.viewWithIdentifier("my_button", ofType: UIButton.self)
try await eventGenerator.fingerTap(at: myButton)
```

This method will throw an error if the view was not found in the hierarchy. If you're testing navigation or screen changes and you need to wait until the view appears, you can add a timeout. This will wait until the hierarchy has updated and return the view.

```swift
let myButton = try await eventGenerator.viewWithIdentifier("my_button", ofType: UIButton.self, timeout: 1)
try await eventGenerator.fingerTap(at: myButton)
```

You can also pass accessibility identifiers directly to the event methods.

```swift
try await eventGenerator.fingerDown(at: "my_draggable_object")
try await eventGenerator.fingerMove(to: "drop_target", duration: 0.5)
try await eventGenerator.fingerUp()
```

### SwiftUI

SwiftUI views don't create a UIView for every element, so Hammer finds them through their accessibility elements instead. Give the elements you want to interact with an accessibility identifier and use it as the location, or to wait for them.

```swift
Toggle("Notifications", isOn: $isOn)
    .accessibilityIdentifier("notifications_toggle")
```

```swift
let eventGenerator = try await EventGenerator(view: SettingsView())
try await eventGenerator.fingerTap(at: "notifications_toggle")
try await eventGenerator.waitUntilVisible("saved_label")
```

A tap on an element uses its activation point, so a toggle is tapped on its switch. An element scrolled out of view is not visible, and tapping it throws.

### Waiting

You will often need to wait for the simulator to finish displaying something on the screen or for an animation to end. Hammer provides multiple methods to wait until a view is visible on screen or if a control is hittable. They check every frame, and wait up to `settings.waitTimeout` unless you pass a timeout. Timeouts leave out the time the main thread is stalled without running, such as on an overloaded CI machine, so they only count the time the app had to respond.

```swift
try await eventGenerator.waitUntilVisible("my_label")
try await eventGenerator.waitUntilHittable("my_button", timeout: 1)
```

You can also wait for any condition, or for a fixed time.

```swift
try await eventGenerator.waitUntil(viewModel.isLoaded)
try await eventGenerator.wait(0.5)
```

### Finishing

When you are done with an event generator, finish it. This lifts any fingers, stylus or keys still down, waits for UIKit to process that, and removes the windows Hammer added. An event generator that is released without finishing does the same, but it has to block the main thread to do it.

```swift
try await eventGenerator.finish()
```

### Settings

`EventGenerator.settings` holds the settings every new event generator starts with, such as timeouts. Each event generator has its own copy in `eventGenerator.settings`, so a test can change it without affecting other tests.

```swift
EventGenerator.settings.waitTimeout = 5
eventGenerator.settings.eventProcessingTimeout = 10
```

### Swift Testing

Hammer works with [Swift Testing](https://developer.apple.com/xcode/swift-testing/) too. Tests that use it must run on the main actor, and should finish their event generators since Swift Testing has no tear down. Only the most recently created event generator that is not finished can send events, since their windows overlap, so tests that use Hammer must not run in parallel. `.serialized` covers one suite and the suites nested in it; tests in other suites still run in parallel unless parallel testing is turned off.

```swift
@MainActor
@Suite(.serialized)
struct MyViewTests {
    @Test
    func buttonTap() async throws {
        let eventGenerator = try await EventGenerator(view: myView)
        try await eventGenerator.fingerTap(at: "my_button")
        try await eventGenerator.finish()
    }
}
```

### Synchronous Tests

Every async method also has a synchronous version with the same name and parameters, so tests that are not async keep working. Swift picks the synchronous version when the calling code is not async.

```swift
func testButtonTap() throws {
    let eventGenerator = try EventGenerator(view: myView)
    try eventGenerator.fingerTap(at: "my_button")
}
```

The synchronous versions keep the main run loop running while they wait, like `XCTestCase.wait(for:timeout:)`. Prefer async tests for new code.

### Upgrading from 1.x

- Make tests async and add `await`, or keep them synchronous as they are.
- Hammer now needs Swift 6, iOS 17 and the main actor.
- Waits check every frame, so `checkInterval` is gone.
- Timeouts are optional and default to `settings.waitTimeout`.

## Troubleshooting

- The app or window is not ready for interaction

Make sure you are running your unit tests in a host application ([setup instructions](#setup)). To interact with a view, it must be visible on the screen and the application must have finished presenting. The error includes the check that did not pass:

  - *The window's scene is not foreground active*: the host app is in the background or covered by a system alert. This usually means the simulator is in a bad state; rebooting it fixes it.
  - *No frame was rendered*: the app is not drawing to the screen, usually for the same reasons.
  - *The application is ignoring interaction events* or *the root view controller is being presented, dismissed or moved*: a transition is still running. Wait for it to finish before creating the `EventGenerator`.

  You can increase the time Hammer waits with `EventGenerator.settings.windowReadyTimeout`.

- The touch was not delivered to the app

UIKit processed the event but did not begin a touch in any of the app's windows. Check that the window is attached to the app's active scene.

- UIKit did not process the generated event

The main thread did not get to the event in time, for example because it is blocked by other work. You can increase the time Hammer waits with `EventGenerator.settings.eventProcessingTimeout`.

- View is not in hirarchy / Unable to find view

Make sure the view you specified is in the same hierarchy as the view that was used to create the `EventGenerator`. If you used an accessibility identifier, check that it was spelled correctly.

- View is not visible

This means that the view is in the hierarchy but is not currently visible on screen, so it's not possible to generate touches for it. Make sure that the view is within visible bounds, not covered by other views, not hidden, and with alpha greater than 0.01.

- View is not hittable

This means that the view is in the hierarchy and visible on screen but is not currently able to receive touches. Make sure that the view reponds to hit test in its center coordinate and user interaction is enabled.

## License

Hammer is released under the Apache License. See [LICENSE](./LICENSE)
