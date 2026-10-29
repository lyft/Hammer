# The hammer command line tool

`hammer` drives an app that runs the [Hammer agent](../agent/getting-started.md), from the Mac. It sends real touches and key presses from inside the app, so it works for scripts, quick checks and AI agents alike.

## Install

Each release has a prebuilt `hammer` for macOS:

```bash
mkdir -p ~/.local/bin
curl -fsSL https://github.com/lyft/Hammer/releases/latest/download/hammer-macos.zip -o /tmp/hammer-macos.zip
unzip -o /tmp/hammer-macos.zip -d ~/.local/bin
```

From a checkout of this repo you can use `swift run hammer` instead.

## First steps

With the app running in the simulator, see what is on screen:

```bash
hammer describe
```

It prints the elements on screen as JSON, each with a `ref` such as `e12`, its identifier, label, value, traits, frame and whether touches reach it (`hittable`). Then act on an element and check the result:

```bash
hammer tap --identifier sign_in
hammer type-text --identifier email --text "me@example.com"
hammer wait-for --identifier home_title --condition visible
hammer screenshot --output screen.png
```

## Getting help

- `hammer commands` lists every command the app runs, including the ones it adds.
- `hammer help <command>` shows a command's arguments and examples.
- `hammer guide` prints a markdown guide for AI agents, with the workflow and every command.

These work without the app running, showing only the built-in commands.

## Next steps

- [Targeting elements](targeting.md): refs, identifiers, labels and points.
- [Live editing](live-editing.md): try view changes in the running app.
- [MCP server](mcp.md): give an AI agent the commands as tools.
- [Errors](errors.md): what failures look like and how to handle them.
- [Commands](commands.md): every built-in command.
