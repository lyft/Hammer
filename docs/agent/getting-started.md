# Adding the agent to an app

`HammerAgent` runs inside your app and lets the [`hammer` command line tool](../cli/getting-started.md), its MCP server and scripts drive it with Hammer. Because it runs in the app, it finds elements by accessibility identifier, label, value or traits, including SwiftUI's, and waits for the app to process each event. It can't reach system UI such as permission alerts or the home screen.

⚠️ IMPORTANT: Like Hammer, the agent uses private APIs. Only start it in debug builds.

## Setup

Add the `HammerAgent` product to your app target, then start the agent when the app launches:

```swift
#if DEBUG
import HammerAgent

let agent = HammerAgent()
try await agent.start()
#endif
```

Keep a reference to `agent` for as long as the app runs, such as in your app delegate.

By default the agent only runs in the simulator and accepts connections from the same device, which includes the Mac running the simulator. See [Security](security.md) to run it on a physical device or require a token.

## Port

The agent listens on port 9876. To use another one, pass `HammerAgent(port:)` or set `HAMMER_AGENT_PORT` for both the app and the tool. In the simulator, launch the app with `SIMCTL_CHILD_HAMMER_AGENT_PORT` to set it:

```bash
SIMCTL_CHILD_HAMMER_AGENT_PORT=9900 xcrun simctl launch booted com.example.MyApp
HAMMER_AGENT_PORT=9900 hammer describe
```

## Next steps

- [Security](security.md): tokens, physical devices and remote connections.
- [Custom commands](custom-commands.md): add commands for your app, such as signing in.
