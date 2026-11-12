# Security on Android

Anything that can reach the agent can control the app, so it is locked down by default:

- It only starts in debuggable builds.
- It only accepts connections from adb's `shell` user, root and the app itself. Any app on the device can connect to an abstract socket, so the agent checks each connection's peer credentials and closes the others before reading them.
- It rejects requests from web browsers, which could reach it through the port `adb forward` opens on the computer, so websites can't control the app.

## Tokens

The Android agent doesn't use a token. iOS reads one from `HAMMER_AGENT_TOKEN` in the app's environment, which Android apps don't have, and the peer check already keeps other apps on the device out. On the Mac, anything that can run `adb` can already control the device.

## No port or remote connections

iOS's `HammerAgent(port:)` and `allowsRemoteConnections` have no Android counterpart. The agent listens on the abstract socket `hammer_<applicationId>`, which only the device can reach, and `hammer` reaches it through adb, over USB or adb's own wireless debugging.

## Release builds

`debugImplementation` keeps the agent out of release builds. If you add it to a build that isn't debuggable, such as a benchmark build, `start()` throws `AgentStartError.ReleaseBuild` unless you pass `allowsReleaseBuild`:

```kotlin
agent.start(allowsReleaseBuild = true)
```

Auto-start never starts in a build that isn't debuggable.

## Physical devices

The agent runs the same on a physical device as on an emulator, with the same peer check: only adb, root and the app can connect. Enable USB debugging and drive it with `hammer --android --serial <serial>`.

The abstract socket namespace is shared by every user of the device, so only one instance of an app can run the agent, such as the personal and not the work profile one.
