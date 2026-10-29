# Finding views

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

## Queries

To find elements by their label, value or traits instead, use an `AccessibilityQuery`. The waiting and visibility methods take queries too.

```swift
try await eventGenerator.fingerTap(at: .label("Sign In", traits: .button))
try await eventGenerator.waitUntilVisible(AccessibilityQuery(label: "Wi-Fi", value: "1"))
```

When multiple elements match, Hammer prefers the visible ones and then the actionable ones like buttons and controls. Elements that activate at the same point, like a button and its title label, count as one. If it still can't choose it throws, unless you turn off `settings.throwOnMultipleMatches` to use the first match. Prefer making the query more specific.

## SwiftUI

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

A tap on an element uses its activation point, so a toggle is tapped on its switch. An element scrolled out of view is not visible, and tapping it throws. Accessibility doesn't say if an element is hidden with `.hidden()` or almost transparent, so Hammer treats those as visible.

To explore a screen of the running app and find its identifiers and labels, use the [`hammer` command line tool](../cli/getting-started.md).
