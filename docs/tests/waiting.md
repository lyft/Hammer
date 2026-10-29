# Waiting, finishing and settings

## Waiting

You will often need to wait for the simulator to finish displaying something on the screen or for an animation to end. Hammer provides multiple methods to wait until a view is visible on screen or if a control is hittable. They check every frame, and wait up to `settings.waitTimeout` unless you pass a timeout. Timeouts leave out the time the main thread is stalled without running, such as on an overloaded CI machine, so they only count the time the app had to respond.

```swift
try await eventGenerator.waitUntilVisible("my_label")
try await eventGenerator.waitUntilHittable("my_button", timeout: 1)
try await eventGenerator.waitUntilExists("results_list", timeout: 5)
try await eventGenerator.waitUntilAnimationsAreFinished()
```

You can also wait for any condition, or for a fixed time.

```swift
try await eventGenerator.waitUntil(viewModel.isLoaded)
try await eventGenerator.wait(0.5)
```

Event methods already wait for UIKit to process each event, so you only need to wait for what the app does in response, such as a navigation, a network stub or an animation. Prefer waiting for a condition over a fixed time.

## Finishing

When you are done with an event generator, finish it. This lifts any fingers, stylus or keys still down, waits for UIKit to process that, and removes the windows Hammer added. An event generator that is released without finishing does the same, but it has to block the main thread to do it.

```swift
try await eventGenerator.finish()
```

## Settings

`EventGenerator.settings` holds the settings every new event generator starts with, such as timeouts. Each event generator has its own copy in `eventGenerator.settings`, so a test can change it without affecting other tests.

```swift
EventGenerator.settings.waitTimeout = 5
eventGenerator.settings.eventProcessingTimeout = 10
```

Change `EventGenerator.settings` in `setUp` and restore it in `tearDown`, so it doesn't leak into other tests.
