# Android

`hammer --android` drives Android apps that run a Hammer agent. The agent serves the same [HTTP API](../internal/http-api.md) on the abstract socket `hammer_<applicationId>`, and `hammer` reaches it through `adb forward`, so commands, errors and the MCP server work the same as on iOS.

```bash
hammer commands --android
hammer describe --android
hammer mcp --android
```

## Getting an agent

Add Hammer's Android agent to your app's debug builds with one line of Gradle, and it starts when the app launches:

```kotlin
debugImplementation("com.lyft.hammer:hammer-agent-android:<version>")
```

See [Adding the agent to an Android app](../android/getting-started.md). Until the app runs, `hammer commands --android` lists the built-in commands, and calls fail with `unreachable`. Other agents implement the [Android transport](../internal/http-api.md#android-transport) and the [built-in commands](../internal/commands.md).

## On Linux

The Linux build of `hammer` drives Android only: iOS needs a Mac, and `--system` without `--android` fails. It is statically linked, so it needs nothing else installed but adb.

## Picking the device and app

- `--serial <serial>` picks the device or emulator, as `adb devices` lists it. It defaults to `ANDROID_SERIAL`, or the only device that is ready.
- `--app-id <application id>` picks the app. It defaults to the only app running an agent, or the focused one when several are.

Both only apply with `--android`, so iOS commands can still take parameters named `serial` and `app_id`. `--android` itself chooses the platform before `hammer` knows it, so no command can take a parameter named `android`. `--port` and `--udid` don't apply with `--android`, and `hammer` rejects them.

A `no_device` error lists the attached devices and their states, such as `unauthorized` when the device still shows the USB debugging prompt. An `unreachable` error lists the apps that run an agent.

`hammer` finds `adb` in `ANDROID_HOME` or `ANDROID_SDK_ROOT`, in Android Studio's default SDK (`~/Library/Android/sdk` on macOS, `~/Android/Sdk` on Linux), or on the `PATH`, and fails with `no_device` and how to install it when there is none. It stops any adb call after 30 seconds with SIGTERM, then SIGKILL, and returns once adb exits, even if a server adb started keeps its output open. It forwards a local port to the app's socket once and reuses that forward, so `adb forward --list` shows one per app; `adb forward --remove-all` removes them. The MCP server also keeps the device and app it found until a call can't reach the agent.

## System UI

`--system` runs `describe`, `tap`, `swipe`, `edge_swipe`, `type_text`, `press_key` and `screenshot` on the whole screen through adb, to reach permission dialogs, the notification shade, the home screen and other apps. See [System UI](system-ui.md#android).

## Built-in commands

An Android agent runs `describe`, `tap`, `long_press`, `swipe`, `edge_swipe`, `drag`, `pinch`, `type_text`, `press_key`, `wait_for`, `wait_for_idle` and `screenshot`, with the arguments and output of the [built-in commands](../internal/commands.md). [On Android](../internal/commands.md#on-android) lists the rules every Android agent follows: dp coordinates, how elements get their identifier, label, value and traits, the order of windows, and `deviceBack`, which goes back like the device's back button. [How it works](../android/getting-started.md#how-it-works) covers what's particular to Hammer's agent, such as how it sends events and what screenshots leave out.

## Security

Any app on the device can connect to an abstract socket, so the [Android transport](../internal/http-api.md#android-transport) requires the agent to accept only adb's `shell` user, root and the app itself. `hammer` can't check this, so it is up to the agent; Hammer's agent does, see [Security on Android](../android/security.md). `HAMMER_AGENT_TOKEN` is sent as on iOS, for agents that also require a token. Hammer's agent doesn't.

## Limits

- `hierarchy`, `inspect` and live editing are not available.
- Android freezes an app soon after it leaves the screen, and its agent can't respond until it's in front again. When a call takes more than 5 seconds, `hammer` checks whether the app is frozen and fails with `app_frozen` instead of waiting.
- Tested with platform tools 37 and Android 9 (API 28) and 17 (API 37) emulators, in portrait and landscape, with gesture and 3-button navigation. Not yet tested on a physical device.
