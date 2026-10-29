<p align="center"><img src="https://user-images.githubusercontent.com/585835/116218212-273b4880-a6ff-11eb-93ec-7c28d821f620.png" alt="" width="80" height="80"></p>
<h1 align="center">Hammer</h1>
<p align="center">If you can't touch this, it's Hammer time!</p>

<p align="center"><img src="https://user-images.githubusercontent.com/585835/116217617-ab410080-a6fe-11eb-9de1-3d42f7dd6037.gif" alt="Demo"></p>

Hammer is a touch, stylus and keyboard synthesis library for emulating user interaction events. It enables better ways of triggering UI actions in unit tests, replicating a real world environment as much as possible.

- **Real events:** touches and key presses go through UIKit like a user's, so gesture recognizers, controls and SwiftUI handle them as they would on a device.
- **Tests:** tap, swipe, drag, pinch and type in XCTest or Swift Testing, finding views by accessibility identifier, label, value or traits.
- **Running apps:** the `hammer` command line tool and AI agents can drive an app that runs Hammer's agent, see what's on screen and try view changes live.

⚠️ IMPORTANT: This library makes extensive use of private APIs and should never be included in a production app.

## Installation

Hammer requires Swift 6.0 and iOS 17.0 or later. Add it with [SwiftPM](https://swift.org/package-manager):

```swift
.package(url: "https://github.com/lyft/Hammer.git", from: "2.0.0")
```

Add the `Hammer` product to your test target, and `HammerAgent` to your app to drive it with the command line tool. CocoaPods is [deprecated](docs/tests/getting-started.md#with-cocoapods-deprecated).

## Writing tests

Hammer tests need a [host application](docs/tests/getting-started.md#host-application) to send touches. Create an `EventGenerator` for the view, view controller, SwiftUI view or window you test, then send it events:

```swift
@MainActor
final class SignInTests: XCTestCase {
    func testSignIn() async throws {
        let eventGenerator = try await EventGenerator(viewController: SignInViewController())

        try await eventGenerator.fingerTap(at: "email_field")
        try await eventGenerator.keyType("me@example.com")
        try await eventGenerator.fingerTap(at: .label("Sign In", traits: .button))
        try await eventGenerator.waitUntilVisible("home_title")
    }
}
```

Locations can be an accessibility identifier, an `AccessibilityQuery`, a view or a point. A few more of what you can do:

```swift
try await eventGenerator.fingerSwipe(at: "list", direction: .up)
try await eventGenerator.fingerEdgeSwipe(direction: .right)
try await eventGenerator.fingerDrag(from: "card", to: "trash", duration: 0.5)
try await eventGenerator.fingerPinch(fromDistance: 100, toDistance: 50, duration: 0.5)
try await eventGenerator.keyPress(.returnOrEnter)
try await eventGenerator.waitUntilHittable("checkout_button")
```

Learn more:

- [Getting started](docs/tests/getting-started.md)
- [Touches](docs/tests/touches.md) and [keyboard](docs/tests/keyboard.md)
- [Finding views and SwiftUI](docs/tests/finding-views.md)
- [Waiting](docs/tests/waiting.md) and [Swift Testing](docs/tests/swift-testing.md)
- [Troubleshooting](docs/tests/troubleshooting.md)

## Driving a running app

Start the agent in a debug build of your app. By default it only runs in the simulator and only accepts connections from the same Mac:

```swift
#if DEBUG
import HammerAgent

let agent = HammerAgent()
try await agent.start()
#endif
```

Install the prebuilt `hammer` tool from the latest release:

```bash
mkdir -p ~/.local/bin
curl -fsSL https://github.com/lyft/Hammer/releases/latest/download/hammer-macos.zip -o /tmp/hammer-macos.zip
unzip -o /tmp/hammer-macos.zip -d ~/.local/bin
```

Then see what's on screen and act on it:

```bash
hammer describe                      # Elements on screen, each with a ref such as e12
hammer tap --ref e12
hammer type-text --identifier email --text "me@example.com"
hammer wait-for --identifier home_title --condition visible
hammer screenshot --output screen.png
hammer help swipe                    # Arguments and examples of a command
```

To give an AI agent the same commands as tools, run `hammer mcp` as an MCP server. For example, with Claude Code:

```bash
claude mcp add hammer -- ~/.local/bin/hammer mcp
```

Learn more:

- [Adding the agent](docs/agent/getting-started.md) and [security](docs/agent/security.md), including tokens and physical devices
- [Using the command line tool](docs/cli/getting-started.md) and [every command](docs/cli/commands.md)
- [Live editing](docs/cli/live-editing.md) views before changing them in code
- [Custom commands](docs/agent/custom-commands.md) for your app
- [MCP server and agent skills](docs/cli/mcp.md)

## Documentation

Every guide is in [docs](docs/README.md).

## License

Hammer is released under the Apache License. See [LICENSE](./LICENSE)
