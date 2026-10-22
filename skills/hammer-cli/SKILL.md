---
name: hammer-cli
description: Drive and inspect a running iOS app that has Hammer's agent started, with the `hammer` command line tool. Use when asked to tap, swipe, type, check what is on screen, take a screenshot or verify a UI change in the app, in the simulator or on a device.
---

# Hammer CLI

`hammer` talks to `HammerAgent` running inside the app and sends real touches and key presses from inside it.

1. Run `hammer guide` first. It prints the full instructions and every command the app runs, including the ones the app adds, so it is always up to date.
2. Start each task with `hammer describe` to see the elements on screen and their refs.
3. Act with a command such as `hammer tap --ref e12`, then check the result with `hammer wait-for`, `hammer describe` or `hammer screenshot` (open the PNG path it prints).

When a command fails it prints `error:` and `hint:` lines. Follow the hint, such as calling `describe` again or fixing an argument, instead of retrying the same call. Exit code 2 means the call itself was invalid; run `hammer help <command>` to see its arguments and examples.

If no agent is listening, the app is not running or has not called `HammerAgent().start()`. Launch it and try again. Pass `--port` when the app uses a port other than 9876.

To turn what you found into a unit test, use the `hammer-tests` skill. The identifiers and labels from `describe` work as the same queries in tests.
