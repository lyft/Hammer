# System UI

The agent runs inside the app, so it can't see or touch system UI such as permission alerts, the home screen or other apps. `--system` runs a command on the whole screen from the Mac instead: in the simulator the way you would click in Simulator.app, and on Android through adb, the way a person holding the device would. The app doesn't need to change, and it doesn't need to be running.

```bash
hammer describe --system
hammer tap --system --label Allow --traits button
```

`describe --system` lists the accessibility elements on screen:

```json
[
  {"frame": {"x": 57, "y": 494, "width": 140, "height": 48}, "label": "Don’t Allow", "traits": ["button"], "type": "Button"},
  {"frame": {"x": 205, "y": 494, "width": 140, "height": 48}, "label": "Allow", "traits": ["button"], "type": "Button"}
]
```

## What it supports

- **Commands:** `describe` and `tap`. Run other commands without `--system`, in the app.
- **Targets:** `--identifier`, `--label`, `--value` and `--traits` (`button`, `link`, `header`, `image`, `staticText`, `searchField`), or `--x` and `--y`. Elements have no refs.
- **Coordinates:** screen points, the same as the frames from `describe --system`.

When no element matches, the `not_found` error lists the buttons on screen.

## Picking the simulator

`--system` drives the only booted simulator. When several are booted, pass `--udid <udid>` or set `HAMMER_SIMULATOR_UDID`. A `no_simulator` error lists the booted ones.

`hammer` uses the frameworks of the selected Xcode, from `DEVELOPER_DIR` or `xcode-select`, so it only works in the simulator. Reading the screen also needs Simulator.app running; `open -a Simulator` starts it.

## Android

With `--android`, `--system` runs through adb's `shell` user, which can read and touch every window:

```bash
hammer describe --android --system
hammer tap --android --system --identifier permission_allow_foreground_only_button
hammer edge-swipe --android --system --direction down --distance 400
hammer press-key --android --system --key deviceHome
```

- **Commands:** `describe`, `tap`, `swipe`, `edge_swipe`, `type_text`, `press_key` and `screenshot`.
- **Elements:** `describe` reads the accessibility nodes of every window on screen with `uiautomator dump`, back to front, such as the app, the status bar, the navigation bar and a permission dialog. Android 9 and earlier only list the active window. Each window is listed with its title or the package that owns it, such as `com.android.systemui`. A node's identifier is its resource id name and its label its content description or text, as in the app's agent. A text field's value is its text, and a switch's or checkbox's is `1` or `0`.
- **Targets:** `--identifier`, `--label`, `--value` and `--traits`, or `--x` and `--y`. Elements have no refs. The traits match the app's agent: `toggleButton` for a switch or checkbox, else `button` for a clickable node, `image` for an image with a content description and `staticText` for text, plus `selected` when it is selected or checked and `notEnabled`.
- **Coordinates:** screen dp, the same as the app's agent, in the screen's current rotation.
- **Gestures:** `edge_swipe` reaches the system's gestures, such as down from the top for the notification shade. Going home or back by swiping only works with gesture navigation; `press_key` with `deviceHome`, `deviceBack` or `appSwitch` presses the device's buttons with any navigation. Its other keys are the keyboard's, so `home` is the keyboard's Home key, as in the app's agent. `tap` has no `count`, since adb can't tap twice quickly enough for a double tap.
- **Typing:** `type_text` types printable ASCII only, since it uses `input text`. With a target, it taps it and waits up to 3 seconds for the text field there to take focus, and fails with `timed_out` otherwise, so it never types into another field that already had focus.
- **Screenshots:** `screencap` captures the whole screen, including the surfaces of maps and videos that the app's agent shows as blank.
- **Speed:** `describe` takes 2 to 3 seconds, and a command that finds an element as long, since it reads the screen first. uiautomator waits for accessibility events to stop first, so on a screen that keeps changing it can fail with `timed_out` after about 30 seconds; wait and try again.

`--serial` picks the device, as for the app's commands.

## MCP

The tools the system driver runs take a `system` argument that does the same, such as `{"system": true, "label": "Allow"}`. Set `HAMMER_SIMULATOR_UDID` in the server's environment to pick the simulator, or `ANDROID_SERIAL` for an Android device.
