# Android

`hammer --android` drives Android apps that run a Hammer agent. The agent serves the same [HTTP API](../internal/http-api.md) on the abstract socket `hammer_<applicationId>`, and `hammer` reaches it through `adb forward`, so commands, errors and the MCP server work the same as on iOS.

```bash
hammer commands --android
hammer describe --android
hammer mcp --android
```

## Getting an agent

Hammer doesn't ship an Android agent yet. An app runs one by implementing the [Android transport](../internal/http-api.md#android-transport): the socket, the peer check, the routes and the [built-in commands](../internal/commands.md) described by `BuiltinCommands.all(for: .android)`. Until the app runs, `hammer commands --android` lists those built-in commands, and calls fail with `unreachable`.

## Picking the device and app

- `--serial <serial>` picks the device or emulator, as `adb devices` lists it. It defaults to `ANDROID_SERIAL`, or the only device that is ready.
- `--app-id <application id>` picks the app. It defaults to the only app running an agent, or the focused one when several are.

Both only apply with `--android`, so iOS commands can still take parameters named `serial` and `app_id`. `--port` and `--udid` don't apply with `--android`, and `hammer` rejects them.

A `no_device` error lists the attached devices and their states, such as `unauthorized` when the device still shows the USB debugging prompt. An `unreachable` error lists the apps that run an agent.

`hammer` finds `adb` in `ANDROID_HOME` or `ANDROID_SDK_ROOT`, in Android Studio's default SDK, or on the `PATH`, and stops any adb call after 30 seconds. It forwards a local port to the app's socket once and reuses that forward, so `adb forward --list` shows one per app; `adb forward --remove-all` removes them. The MCP server also keeps the device and app it found until a call can't reach the agent.

## Security

Any app on the device can connect to an abstract socket, so the [Android transport](../internal/http-api.md#android-transport) requires the agent to accept only adb's `shell` user, root and the app itself. `hammer` can't check this, so it is up to the agent. `HAMMER_AGENT_TOKEN` is sent as on iOS, for agents that also require a token.

## Limits

- `--system` is not available yet.
- Android freezes an app soon after it leaves the screen, and its agent can't respond until it's in front again. When a call takes more than 5 seconds, `hammer` checks whether the app is frozen and fails with `app_frozen` instead of waiting.
- Tested with platform tools 37 and Android 9 (API 28) and 17 (API 37) emulators.
