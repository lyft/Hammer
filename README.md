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

Hammer requires Swift 5.3 and iOS 11.0 or later.

#### With [SwiftPM](https://swift.org/package-manager)

```swift
.package(url: "https://github.com/lyft/Hammer.git", from: "0.13.0")
```

#### With [CocoaPods](https://cocoapods.org/)

```ruby
pod 'HammerTests', '~> 0.13.1'
```

## Setup

Hammer unit tests need to run in a host application to be able to generate touches. To configure this select your project in the sidebar, select your test target, and choose a host application in the general tab. The host application can be your main application or an empty wrapper like [TestHost](./TestHost).

SwiftPM does not currently support creating applications. To use Hammer with SwiftPM frameworks you need to create an xcodeproj and setup a host application.

## Usage

Hammer allows you to simulate fingers, stylus and keyboard events. It also provides various convenience methods to simulate higher level user interactions.

To be able to send events to a view you must first create an `EventGenerator`:

```swift
// Initialize for an existing UIWindow, ensure that the window is key and visible.
let eventGenerator = EventGenerator(window: myWindow)

// Initialize for a UIView, automatically wrapping it in a temporary window.
let eventGenerator = EventGenerator(view: myView)

// Initialize for a UIViewController, automatically wrapping it in a temporary window.
let eventGenerator = EventGenerator(viewController: myViewController)
```

When simulating finger or stylus touches, there are multiple ways of specifying a touch location:

1. Default: If you don't specify a location it will use the center of the screen.
2. Point: A CGPoint in screen coordinates.
3. View: A reference to a UIView or UIViewController, the location will be the center of the visible part of the view.
4. Identifier: An accessibility identifier string of a view, the location will be the center of the visible part of the view.

By default, Hammer will display simulated touches over the view. You can change this behavior for your event generator.

```swift
eventGenerator.showTouches = false
```

### Simulating Fingers

Fingers are the most common method of user interaction on iOS. Hammer supports handling multiple fingers on the screen simultaneously, up to the limit on the device. You can specify the specific finger index you would like to use, if unspecified it will choose the most appropriate one automatically.

Primitive events are the basic building blocks of user interactions, they can be combined together to create full gestures. Some methods will allow you to specify a duration and will interpolate the changes during that time.

```swift
try eventGenerator.fingerDown(at: CGPoint(x: 10, y: 10))
try eventGenerator.fingerMove(to: CGPoint(x: 20, y: 10), duration: 0.5)
try eventGenerator.fingerUp()
```

For convenience, Hammer provides many higher level gestures. If you don't specify a location it will automatically default to the center of the view.

```swift
try eventGenerator.fingerTap()
try eventGenerator.fingerDoubleTap()
try eventGenerator.fingerLongPress()
try eventGenerator.twoFingerTap()
```

Many advanced gestures are also available.

```swift
try eventGenerator.fingerDrag(from: CGPoint(x: 10, y: 10), to: CGPoint(x: 20, y: 10), duration: 0.5)
try eventGenerator.fingerPinch(fromDistance: 100, toDistance: 50, duration: 0.5)
try eventGenerator.fingerRotate(angle: .pi, duration: 0.5)
```

### Simulating Stylus

Stylus is available when running on an iPad. It allows for additional properties like pressure, altitude and azimuth to be specified.

Similar to fingers, primitive events are the basic building blocks of stylus interactions.

```swift
try eventGenerator.stylusDown(at: CGPoint(x: 10, y: 10), azimuth: 0, altitude: 0, pressure: 0.5)
try eventGenerator.stylusMove(to: CGPoint(x: 20, y: 10), duration: 0.5)
try eventGenerator.stylusUp()
```

Hammer also provides many higher level gestures for Stylus. If you don't specify a location it will automatically default to the center of the view.

```swift
try eventGenerator.stylusTap()
try eventGenerator.stylusDoubleTap()
try eventGenerator.stylusLongPress()
```

### Simulating Keyboard

Keyboard methods take an explicit `KeyboardKey` object or a `Character`. Characters will be mapped to their closest keyboard key, you must wrap them with a shift key modifier if needed. This means that specifying a lowercase "a" character is equivalent to specifying an uppercase "A", this is also true for keys with symbols.

```swift
// Explicit `KeyboardKey`
try eventGenerator.keyDown(.letterA)
try eventGenerator.keyUp(.letterA)

// Automatic `Character` mapping
try eventGenerator.keyDown("a")
try eventGenerator.keyUp("a")

// Convenience key down and up events
try eventGenerator.keyPress(.letterA)
try eventGenerator.keyPress("a")
```

To type characters or longer strings and get automatic shift wrapping you can use the `keyType()` methods.

```swift
try eventGenerator.keyType("This will type the string as specified, including symbols!")
```

### Finding a subview

When running on a full screen app or testing navigation, specifying a CGPoint in screen coordinates can be difficult. For this, Hammer provides convenience methods to find views in the hierarchy by their accessibility identifier.

```swift
let myButton = try eventGenerator.viewWithIdentifier("my_button", ofType: UIButton.self)
try eventGenerator.fingerTap(at: myButton)
```

This method will throw an error if the view was not found in the hierarchy. If you're testing navigation or screen changes and you need to wait until the view appears, you can add a timeout. This will wait until the hierarchy has updated and return the view.

```swift
let myButton = try eventGenerator.viewWithIdentifier("my_button", ofType: UIButton.self, timeout: 1)
try eventGenerator.fingerTap(at: myButton)
```

You can also pass accessibility identifiers directly to the event methods.

```swift
try eventGenerator.fingerDown(at: "my_draggable_object")
try eventGenerator.fingerMove(to: "drop_target", duration: 0.5)
try eventGenerator.fingerUp()
```

### Waiting

You will often need to wait for the simulator to finish displaying something on the screen or for an animation to end. Hammer provides multiple methods to wait until a view is visible on screen or if a control is hittable

```swift
try eventGenerator.waitUntilVisible("my_label", timeout: 1)
try eventGenerator.waitUntilHittable("my_button", timeout: 1)
```

## Troubleshooting

- The app or window is not ready for interaction

Make sure you are running your unit tests in a host application ([setup instructions](#setup)). To interact with a view, it must be visible on the screen and the application must have finished presenting. You can test this by adding a delay to your testing and verifying that your view is appearing on screen.

- View is not in hirarchy / Unable to find view

Make sure the view you specified is in the same hierarchy as the view that was used to create the `EventGenerator`. If you used an accessibility identifier, check that it was spelled correctly.

- View is not visible

This means that the view is in the hierarchy but is not currently visible on screen, so it's not possible to generate touches for it. Make sure that the view is within visible bounds, not covered by other views, not hidden, and with alpha greater than 0.01.

- View is not hittable

This means that the view is in the hierarchy and visible on screen but is not currently able to receive touches. Make sure that the view reponds to hit test in its center coordinate and user interaction is enabled.

## License

Hammer is released under the Apache License. See [LICENSE](./LICENSE)
