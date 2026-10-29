# Live editing

You can change views in the running app to see how a change looks, or which one fixes a layout problem, before writing it in code.

1. Find the view with `describe`, or `hierarchy` for containers and hidden views.
2. `inspect` it to see its properties with their types and values, and the constraints that lay it out, with refs such as `c4`.
3. Change it with `set-property`, `set-constraint` or `add-constraint`, and take a `screenshot` to compare.
4. Run `revert` when done.

```bash
hammer inspect --ref e3
hammer set-property --ref e3 --property backgroundColor --to systemBlue
hammer set-constraint --constraint c4 --constant 24
hammer screenshot --ref e3 --output view.png
hammer revert
```

Colors take hex strings such as `"#3366FF"` or names such as `systemBlue`. Rects, sizes, points and insets take JSON objects, which are easiest to pass on [standard input](targeting.md#passing-arguments).

The app keeps changes until it relaunches, so always `revert` before testing anything else. It restores every original value, or only one view's with a target.
