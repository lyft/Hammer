# Hammer documentation

Hammer simulates real touch, stylus and keyboard events on iOS. Use it to write unit tests that interact with your UI like a user, or to drive a running app from the command line and AI agents.

## Writing tests

1. [Getting started](tests/getting-started.md): install Hammer and write your first test.
2. [Touches](tests/touches.md): fingers, gestures and stylus.
3. [Keyboard](tests/keyboard.md): typing and key presses.
4. [Finding views](tests/finding-views.md): identifiers, queries and SwiftUI.
5. [Waiting](tests/waiting.md): waiting for the app, finishing and settings.
6. [Swift Testing](tests/swift-testing.md)
7. [Upgrading from 1.x](tests/upgrading.md)
8. [Troubleshooting](tests/troubleshooting.md)

## Driving a running app

Add the agent to your app:

1. [Getting started](agent/getting-started.md): start the agent in a debug build.
2. [Security](agent/security.md): tokens, physical devices and remote connections.
3. [Custom commands](agent/custom-commands.md): add commands for your app.

Then use the `hammer` command line tool:

1. [Getting started](cli/getting-started.md): install `hammer` and run your first commands.
2. [Targeting elements](cli/targeting.md): refs, identifiers, labels and points.
3. [Live editing](cli/live-editing.md): try view changes in the running app.
4. [MCP server](cli/mcp.md): give AI agents the commands as tools.
5. [Errors](cli/errors.md): error codes and exit codes.
6. [Commands](cli/commands.md): every built-in command.

## Developing Hammer

- [Agent HTTP API](internal/http-api.md): the contract between the agent and its clients.
- [Contributing](../CONTRIBUTING.md)
