# Drivers

The `hammer` CLI and MCP server speak one command language and send each call to a driver that runs it. A driver is any type that conforms to [`Driver`](../../Sources/HammerCLI/Drivers/Driver.swift):

- `catalog()` returns the commands to describe in `commands`, `help` and `guide`.
- `callableCommands()` returns the commands calls are resolved against.
- `run(_:arguments:)` runs one and returns its JSON output, or throws a `ClientError` with an `AgentErrorBody`, so errors look the same whichever driver failed.

| Driver | Folder | Runs |
| --- | --- | --- |
| `AgentClient` | [Drivers/App](../../Sources/HammerCLI/Drivers/App) | Every command, inside the app, through the agent's [HTTP API](http-api.md). |
| `SimulatorDriver` | [Drivers/Simulator](../../Sources/HammerCLI/Drivers/Simulator) | `describe` and `tap` on the simulator's whole screen, from the Mac. |
| `AndroidAgentClient` | [Drivers/Android](../../Sources/HammerCLI/Drivers/Android) | Every command, inside an Android app, through `adb forward` to the agent's [HTTP API](http-api.md). |
| `AndroidSystemDriver` | [Drivers/Android](../../Sources/HammerCLI/Drivers/Android) | `describe`, `tap`, `swipe`, `edge_swipe`, `type_text`, `press_key` and `screenshot` on an Android device's whole screen, through adb. |

The system drivers share [Drivers/Screen](../../Sources/HammerCLI/Drivers/Screen): targets, queries and the describe output for elements read from outside the app.

[`Drivers`](../../Sources/HammerCLI/Drivers/Driver.swift) holds the ones a call can go to, and the caller picks one: the CLI with `--system`, the MCP server with the `system` argument.

## Adding a driver

1. Add a folder under `Sources/HammerCLI/Drivers` with the driver and whatever it needs, such as bindings to a platform's tools. Nothing outside the folder should depend on its internals.
2. Describe its commands with `CommandDescriptor`s that use the built-in commands' names and parameters, leaving out the ones it can't support. Callers then switch drivers without learning a new language.
3. Validate arguments with `CommandDescriptor.validate(_:)` in `run`, since the MCP server passes them unchecked.
4. Report failures with the codes in [AgentWire.swift](../../Sources/HammerAgentCore/AgentWire.swift), adding one only for a kind of failure no code covers.
5. Add it to `Drivers` and to how the CLI and MCP server pick one.

## The simulator driver

It loads Xcode's private frameworks at runtime, the same ones idb and AXe use:

- **Devices:** CoreSimulator's `SimServiceContext` finds the booted simulator, in [CoreSimulator.swift](../../Sources/HammerCLI/Drivers/Simulator/CoreSimulator.swift).
- **Touches:** SimulatorKit's `SimDeviceLegacyHIDClient` sends the Indigo messages Simulator.app sends for clicks, in [SimulatorHID.swift](../../Sources/HammerCLI/Drivers/Simulator/SimulatorHID.swift). Points are fractions of the screen.
- **Elements:** AccessibilityPlatformTranslation's `AXPTranslator` reads the frontmost accessibility tree through `SimDevice`, in [SimulatorAccessibility.swift](../../Sources/HammerCLI/Drivers/Simulator/SimulatorAccessibility.swift). Frames are in screen points.

These APIs can change with each Xcode release. When the driver breaks, check the selectors and the signature of `IndigoHIDMessageForMouseNSEvent` against the new SimulatorKit first.

## The Android system driver

It runs adb's `shell` user, which can read and inject input into every window, unlike an app:

- **Elements:** `uiautomator dump --windows` lists the accessibility nodes of every window on screen, falling back to a plain dump on versions without `--windows`, in [AndroidScreen.swift](../../Sources/HammerCLI/Drivers/Android/AndroidScreen.swift). It dumps to a file in `/data/local/tmp` and prints it in the same shell, since uiautomator can print an error and still exit 0. A dump that failed because the screen was changing is retried. Bounds are pixels, turned into dp with `wm density`.
- **Metrics:** the display's current size from `dumpsys window displays` (`cur=`), since `wm size` is the size in the natural orientation. Commands that don't need it, such as `press_key`, skip it.
- **Input:** `input tap`, `input swipe`, `input text` and `input keyevent`.
- **Screenshots:** `screencap -p`, cropped and scaled with ImageIO.
