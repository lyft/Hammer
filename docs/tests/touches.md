# Touches

Hammer simulates fingers and the stylus. Every touch method takes a location, which can be:

1. Default: If you don't specify a location it will use the center of the screen.
2. Point: A CGPoint in screen coordinates.
3. View: A reference to a UIView or UIViewController, the location will be the center of the visible part of the view.
4. Identifier: An accessibility identifier string of a view or SwiftUI element, the location will be the center of the visible part of the view, or the activation point of the SwiftUI element.
5. Query: An `AccessibilityQuery` that matches the identifier, label, value and traits of a view or SwiftUI element, with the same location as an identifier.

See [Finding views](finding-views.md) for identifiers and queries.

## Fingers

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

Swipes move a finger in a direction, and edge swipes start from the edge of the screen like the swipe to go back in a navigation controller. Any touch that starts at the edge of the screen is marked as an edge touch, so `UIScreenEdgePanGestureRecognizer` recognizes it.

```swift
try await eventGenerator.fingerSwipe(direction: .up)
try await eventGenerator.fingerEdgeSwipe(direction: .right)
```

## Stylus

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
