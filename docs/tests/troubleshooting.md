# Troubleshooting

### The app or window is not ready for interaction

Make sure you are running your unit tests in a host application ([setup instructions](getting-started.md#host-application)). To interact with a view, it must be visible on the screen and the application must have finished presenting. The error includes the check that did not pass:

- *The window's scene is not foreground active*: the host app is in the background or covered by a system alert. This usually means the simulator is in a bad state; rebooting it fixes it.
- *No frame was rendered*: the app is not drawing to the screen, usually for the same reasons.
- *The application is ignoring interaction events* or *the root view controller is being presented, dismissed or moved*: a transition is still running. Wait for it to finish before creating the `EventGenerator`.

You can increase the time Hammer waits with `EventGenerator.settings.windowReadyTimeout`.

### The touch was not delivered to the app

UIKit processed the event but did not begin a touch in any of the app's windows. Check that the window is attached to the app's active scene.

### UIKit did not process the generated event

The main thread did not get to the event in time, for example because it is blocked by other work. You can increase the time Hammer waits with `EventGenerator.settings.eventProcessingTimeout`.

### View is not in hierarchy / Unable to find view / Unable to find element

Make sure the view you specified is in the same hierarchy as the view that was used to create the `EventGenerator`. If you used an accessibility identifier or query, check that it was spelled correctly.

### Found multiple elements

More than one visible and actionable element matches the identifier or query. Make the query more specific, for example by adding traits, or give the elements unique identifiers.

### View is not visible

This means that the view is in the hierarchy but is not currently visible on screen, so it's not possible to generate touches for it. Make sure that the view is within visible bounds, not covered by other views, not hidden, and with alpha greater than 0.01. An element scrolled out of view is not visible either, so swipe the scroll view until it is.

### View is not hittable

This means that the view is in the hierarchy and visible on screen but is not currently able to receive touches. Make sure that the view responds to hit test in its center coordinate, user interaction is enabled and the control is not disabled.

### System alerts

Hammer can only reach the app's own windows, not system UI such as permission alerts, so stub the code that shows them.
