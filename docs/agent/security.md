# Security

Anything that can reach the agent can control the app, so it is locked down by default:

- It only runs in the simulator.
- It only accepts connections from the same device, which includes the Mac running the simulator.
- It rejects requests from web browsers, so websites can't control the app.

## Tokens

Set a token so other processes on the Mac can't control the app. Pass `HammerAgent(token:)` or set `HAMMER_AGENT_TOKEN` for the app (`SIMCTL_CHILD_HAMMER_AGENT_TOKEN` in the simulator), and set `HAMMER_AGENT_TOKEN` to the same value for the tool:

```bash
SIMCTL_CHILD_HAMMER_AGENT_TOKEN=secret xcrun simctl launch booted com.example.MyApp
HAMMER_AGENT_TOKEN=secret hammer describe
```

## Physical devices

To run the agent on a physical device, start it with `allowsPhysicalDevice`. Other apps on the device can connect to it, so use a token.

```swift
try await agent.start(allowsPhysicalDevice: true)
```

To drive the device from a Mac, also pass `allowsRemoteConnections`, which accepts connections from any device on the network. It requires a token, and `start` throws without one.

```swift
let agent = HammerAgent(token: "secret")
try await agent.start(allowsPhysicalDevice: true, allowsRemoteConnections: true)
```
