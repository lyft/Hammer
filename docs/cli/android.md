# Android

`hammer` also drives Android apps that run an Android Hammer agent. The agent serves the same [HTTP API](../internal/http-api.md) on the abstract socket `hammer_<applicationId>`, and `hammer` reaches it through `adb forward`, so commands, errors and the MCP server work the same as on iOS.

```bash
hammer commands --android
hammer describe --android
hammer mcp --android
```

## Picking the device and app

- `--serial <serial>` picks the device or emulator, as `adb devices` lists it. It defaults to `ANDROID_SERIAL`, or the only attached device.
- `--app-id <application id>` picks the app. It defaults to the only app running an agent, or the foreground one when several are.

Either option implies `--android`. A `no_device` error lists the attached devices, and an `unreachable` error lists the apps that run an agent.

`hammer` finds `adb` in `ANDROID_HOME` or `ANDROID_SDK_ROOT`, in Android Studio's default SDK, or on the `PATH`. It opens a port forward for each call and removes it afterwards.

## Security

Any app on the device can connect to an abstract socket, so the agent only answers connections from adb's `shell` user, root and the app itself. The [request rules](../internal/http-api.md#request-rules) still apply, since a browser on the Mac can reach the forwarded port.

## Limits

- `--system` is not available yet.
- With the app not running, `hammer commands --android` lists no commands, since the built-in commands describe the iOS agent.
