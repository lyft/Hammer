<p align="center"><img src="https://user-images.githubusercontent.com/585835/116218212-273b4880-a6ff-11eb-93ec-7c28d821f620.png" alt="" width="80" height="80"></p>
<h1 align="center">Hammer</h1>
<p align="center">If you can't touch this, it's Hammer time!</p>

<p align="center"><img src="https://user-images.githubusercontent.com/585835/116217617-ab410080-a6fe-11eb-9de1-3d42f7dd6037.gif" alt="Demo"></p>

Hammer is a touch, stylus and keyboard synthesis library for emulating user interaction events. It enables better ways of triggering UI actions in unit tests, replicating a real world environment as much as possible. Its agent also lets the `hammer` command line tool and AI agents drive a running app the same way.

⚠️ IMPORTANT: This library makes extensive use of private APIs and should never be included in a production app.

## Installation

Hammer requires Swift 6.0 and iOS 17.0 or later.

```swift
.package(url: "https://github.com/lyft/Hammer.git", from: "2.0.0")
```

## Writing tests

Hammer unit tests run in a host application. Create an `EventGenerator` for the view you test and send it events:

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

See [writing tests](docs/tests/getting-started.md) to get started.

## Driving a running app

Start the agent in a debug build of your app:

```swift
#if DEBUG
import HammerAgent

let agent = HammerAgent()
try await agent.start()
#endif
```

Then drive it from the Mac with the [`hammer` command line tool](docs/cli/getting-started.md), or give an AI agent its [MCP server](docs/cli/mcp.md):

```bash
hammer describe
hammer tap --identifier sign_in
hammer type-text --identifier email --text "me@example.com"
hammer screenshot --output screen.png
```

See [adding the agent](docs/agent/getting-started.md) to get started.

## Documentation

All guides are in [docs](docs/README.md).

## License

Hammer is released under the Apache License. See [LICENSE](./LICENSE)
