# Commands

These are the built-in commands. Run `hammer help <command>` for a command's arguments and examples, and `hammer commands` for the ones your app adds.

## Seeing the screen

| Command | What it does |
| --- | --- |
| `describe` | Lists the elements on screen with their refs, identifiers, labels, values, traits and frames. |
| `hierarchy` | Shows the UIKit view tree, including hidden views and containers. |
| `inspect` | Shows a view's properties, constraints, superview, subviews and view controller. |
| `screenshot` | Saves a PNG of the screen, or of one view. |

## Acting

| Command | What it does |
| --- | --- |
| `tap` | Taps an element or a point, `--count 2` for a double tap. |
| `long-press` | Touches an element or a point and holds it. |
| `swipe` | Swipes over an element, such as to scroll. Swiping up scrolls the content down. |
| `edge-swipe` | Swipes from the edge of the screen, such as right to go back. |
| `drag` | Drags from one element or point to another. |
| `type-text` | Types into the focused field, or taps a field first. |
| `press-key` | Presses a key, such as `returnOrEnter` or `escape`. |

## Waiting

| Command | What it does |
| --- | --- |
| `wait-for` | Waits until an element exists, is visible, is hittable or is gone. |
| `wait-for-idle` | Waits until animations finish. |

## Live editing

| Command | What it does |
| --- | --- |
| `set-property` | Changes a property of a view, such as `backgroundColor` or `isHidden`. |
| `set-constraint` | Changes a constraint's constant, priority or whether it is active. |
| `add-constraint` | Adds a constraint between views, or to a constant. |
| `revert` | Undoes every live change, or one view's. |

See [Live editing](live-editing.md) for how they fit together.
