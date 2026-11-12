---
name: hammer-cli
description: Drive and inspect a running iOS or Android app that has Hammer's agent started, with the `hammer` command line tool. Use when asked to tap, swipe, type, check what is on screen, take a screenshot or verify a UI change in the app, in the simulator or on a device, and to try changes to views live, such as a color, a hidden view or a constraint, before writing them in code.
---

# Hammer CLI

`hammer` talks to `HammerAgent` running inside the app and sends real touches and key presses from inside it.

If `hammer` isn't installed, download the prebuilt one from the latest release: `curl -fsSL https://github.com/lyft/Hammer/releases/latest/download/hammer-macos.zip -o /tmp/hammer-macos.zip && unzip -o /tmp/hammer-macos.zip -d ~/.local/bin`. On Linux, which drives Android only, extract `hammer-linux-x86_64.tar.gz` or `hammer-linux-aarch64.tar.gz` from the same release into `~/.local/bin`.

1. Run `hammer guide` first. It prints the full instructions and every command the app runs, including the ones the app adds, so it is always up to date.
2. Start each task with `hammer describe` to see the elements on screen and their refs.
3. Act with a command such as `hammer tap --ref e12`, then check the result with `hammer wait-for`, `hammer describe` or `hammer screenshot` (open the PNG path it prints).

To try a change live, such as "how does it look with a blue background" or "which constraint fixes this", `hammer inspect` the view, change it with `hammer set-property`, `hammer set-constraint` or `hammer add-constraint`, and compare screenshots. Run `hammer revert` when done, so the app is back to its real state, and then make the change that worked in code.

When a command fails it prints a JSON object with the `error`, a `code` such as `not_found`, `not_hittable` or `timed_out`, and a `hint`. Follow the hint, such as calling `describe` again or fixing an argument, instead of retrying the same call. A `disconnected` or `timed_out` command may still have run, so check the app's state before running it again. Exit code 2 means the call itself was invalid; run `hammer help <command>` to see its arguments and examples.

System UI such as permission alerts, the home screen and other apps is outside the app. Run `hammer describe --system` to see it and `hammer tap --system --label Allow` to tap it, in the simulator or with `--android`. Pass `--udid` when several simulators are booted. On Android, `--system` also swipes, types, presses keys such as `deviceHome` and takes screenshots.

If no agent is listening, the app is not running or has not called `HammerAgent().start()`. Launch it and try again. Pass `--port` when the app uses a port other than 9876, and set `HAMMER_AGENT_TOKEN` to the app's token if it reports a missing token.

For an Android app, add `--android` to every command, such as `hammer describe --android`, and run `hammer guide --android` for the Android guide. `hammer` reaches the app through adb: pass `--serial` when several devices are attached, or set `ANDROID_SERIAL`, and `--app-id` when several apps run an agent. If no agent is listening, launch a debug build of the app; if the app has no agent yet, add `debugImplementation("com.lyft.hammer:hammer-agent-android:<version>")` to its Gradle dependencies, which starts one when a debug build launches. An `unreachable` error lists the apps that do run one, and a `no_device` error lists the devices and their states, such as `unauthorized` while the device shows the USB debugging prompt.

To turn what you found into a unit test, use the `hammer-tests` skill. The identifiers and labels from `describe` work as the same queries in tests.
