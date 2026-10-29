# Targeting elements

Commands that act on an element take one of:

- **A ref:** `--ref e12`, from `describe`. It is the most precise target and stays the same while the element exists. If a ref is unknown, run `describe` again.
- **Accessibility:** `--identifier`, `--label`, `--value` and `--traits`. Every one you give must match. When several elements match, add more of them or use the ref.
- **A point:** `--x` and `--y` in window points, the same coordinates as the frames from `describe`.

Without a target, gestures use the center of the window.

```bash
hammer tap --ref e12
hammer tap --label Continue --traits button
hammer tap --x 120 --y 340
```

`describe` only lists elements with accessibility information. Use `describe --all` for every visible view, or `hierarchy` for the full UIKit view tree, including hidden views and containers.

## Passing arguments

- **Options:** `--name value` or `--name=value`.
- **Lists:** comma separated, such as `--traits button,selected`.
- **Booleans:** `--all` is the same as `--all true`.
- **JSON:** a trailing `-` reads a JSON object of arguments from standard input, for nested values:

```bash
echo '{"ref": "e3", "property": "frame", "to": {"x": 0, "y": 0, "width": 100, "height": 44}}' \
    | hammer set-property -
```

## Output

Output is JSON on standard output. `--output <path>` writes it to a file instead. Screenshots are always written to a PNG file, and `hammer` prints its path.
