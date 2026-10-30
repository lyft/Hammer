# System UI

The agent runs inside the app, so it can't see or touch system UI such as permission alerts, the home screen or other apps. In the simulator, `--system` runs a command on the whole screen from the Mac instead, the way you would click in Simulator.app. The app doesn't need to change, and it doesn't need to be running.

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

`hammer` uses the frameworks of the selected Xcode, from `DEVELOPER_DIR` or `xcode-select`, so it only works in the simulator.

## MCP

The `describe` and `tap` tools take a `system` argument that does the same, such as `{"system": true, "label": "Allow"}`. Set `HAMMER_SIMULATOR_UDID` in the server's environment to pick the simulator.
