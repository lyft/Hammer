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

It runs through the system helper when it can, in [android/hammer-system](../../android/hammer-system), and otherwise through adb's `shell` user, which can read and inject input into every window, unlike an app. Both read into the same elements, behind the `SystemScreen` protocol in [SystemScreen.swift](../../Sources/HammerCLI/Drivers/Android/SystemScreen.swift).

### The system helper

- **What it is:** an instrumentation APK whose `SystemServer` holds UiAutomation with `FLAG_RETRIEVE_INTERACTIVE_WINDOWS`, and answers the same HTTP API as the app's agent on the abstract socket `@hammer_system`, with the agent's server, router and JSON code, which both share from [hammer-core](../../android/hammer-core). Its commands take pixels; the tool turns dp into pixels. Only adb's shell user and root may connect.
- **Embedding:** Release.yml builds the release APK, shrunk to about 180 KB, and [embed-system-helper.sh](../../scripts/embed-system-helper.sh) writes it base64 encoded into `SystemHelperAPK.swift` before the macOS and Linux tools are built. A tool built from a checkout has none, and runs through uiautomator unless `HAMMER_SYSTEM_HELPER_APK` names one, built with `./gradlew :hammer-system:assembleRelease` in `android`.
- **Lifecycle:** in [AndroidSystemHelper.swift](../../Sources/HammerCLI/Drivers/Android/AndroidSystemHelper.swift). A command first asks a running helper for its `version`, the SHA-256 of its APK, and replaces a helper that differs. It installs with `adb install -r -t`, after uninstalling a helper signed with another key. `am instrument -w` hosts the UiAutomation connection, since without `-w` Android gives the instrumentation none, so it runs detached on the device with `setsid nohup`. The start watches the helper's socket and the `am` process, and a helper that exits, such as when another tool holds UiAutomation, fails the start at once with the reason it wrote to logcat under `HammerSystem`; one that times out is killed, so it can't take UiAutomation later. A failed start is kept for 30 seconds in the host's temporary directory, so commands don't each wait for it, and starts for one device take turns through a file lock there.
- **Proof:** an abstract socket name is open to any app, which could take `@hammer_system` first and read every typed text. Each start writes a new 32-byte secret, as hex, to `/data/local/tmp/hammer-system-secret` with `umask 077`, readable by adb's shell user only, and passes it with `am instrument -e secret`. Every request carries a random `X-Hammer-Challenge` and every response the helper's `X-Hammer-Proof`, the HMAC-SHA256 of the challenge under the secret. The tool sends `version` first and nothing else to a server that doesn't prove it; a token sent by the tool would instead hand the secret to whatever listens. The helper itself only accepts adb's shell user and root, by the socket's peer credentials.
- **Interruptions:** adb forward accepts a connection whether or not the helper listens, so a dropped connection can't tell a command the helper never got from one it ran. Only `describe` and `screenshot` fall back to adb; other commands fail and say they may have run.
- **Reads:** UiAutomation caches nodes and updates them from accessibility events, which web views don't send for every change, so each read clears the cache on Android 14 and later.
- **Web content in the app:** the agent can't read what a view only describes to accessibility services, such as a web view's page, so its describe marks such a view `needsSystemRead`, with its `accessibilityClass`. The app client fills the view's children from one helper read of the app's windows, in [SystemReads.swift](../../Sources/HammerCLI/Drivers/Android/SystemReads.swift): the view is the shallowest helper node with its frame, class and identifier, so a page's full-screen child isn't taken for it, and views with one frame take such nodes in order. A web view reports no resource id to accessibility services, so a node without one matches any. A web view builds its tree on the first read, so a read that finds one empty is tried again, up to 3 times; other views aren't. Those elements get refs such as `s1a2b3c4d`, a hash of the element's type, identifier, label and frame but not its value, so a field keeps its ref while text is typed, and nothing is kept between calls: a command with one reads the screen again and taps the element's point through the agent, failing with `not_found` when it moved. A query the agent doesn't find is looked for in the same content. App commands use a helper that runs and only start one with `HAMMER_SYSTEM_HELPER=auto`.

### Through adb

- **Elements:** `uiautomator dump --windows` lists the accessibility nodes of every window on screen, falling back to a plain dump on versions without `--windows`, in [AndroidScreen.swift](../../Sources/HammerCLI/Drivers/Android/AndroidScreen.swift). It dumps to a file in `/data/local/tmp` and prints it in the same shell, since uiautomator can print an error and still exit 0. A dump that failed because the screen was changing is retried. Bounds are pixels, turned into dp with `wm density`.
- **Metrics:** the display's current size from `dumpsys window displays` (`cur=`), since `wm size` is the size in the natural orientation. Commands that don't need it, such as `press_key`, skip it.
- **Input:** `input tap`, `input swipe`, `input text` and `input keyevent`.
- **Screenshots:** the raw pixels of `screencap`, cropped, area-averaged to the scale and encoded as PNG with zlib, so it needs no platform image library.
