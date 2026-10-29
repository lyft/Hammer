# Built-in commands

The behavior of every built-in command, detailed enough to implement it in another agent. The [HTTP API](http-api.md) covers how commands are called and how errors are returned.

The descriptors in [BuiltinCommands.swift](../../Sources/HammerAgentCore/BuiltinCommands.swift) and [BuiltinCommands+Editing.swift](../../Sources/HammerAgentCore/BuiltinCommands+Editing.swift) are the source of truth for names, parameters, summaries and examples. The implementations are in [Sources/HammerAgent/Commands](../../Sources/HammerAgent/Commands). Keep this page in sync when changing either.

| Command | Kind | Platform |
| --- | --- | --- |
| [`describe`](#describe) | Screen | Core |
| [`hierarchy`](#hierarchy) | Screen | Core, with platform view types |
| [`inspect`](#inspect) | Screen | UIKit |
| [`screenshot`](#screenshot) | Screen | Core |
| [`tap`](#tap) | Gesture | Core |
| [`long_press`](#long_press) | Gesture | Core |
| [`swipe`](#swipe) | Gesture | Core |
| [`edge_swipe`](#edge_swipe) | Gesture | Core |
| [`drag`](#drag) | Gesture | Core |
| [`type_text`](#type_text) | Keyboard | Core |
| [`press_key`](#press_key) | Keyboard | Core, with platform key names |
| [`wait_for`](#wait_for) | Waiting | Core |
| [`wait_for_idle`](#wait_for_idle) | Waiting | Core |
| [`set_property`](#set_property) | Live editing | UIKit |
| [`set_constraint`](#set_constraint) | Live editing | UIKit (Auto Layout) |
| [`add_constraint`](#add_constraint) | Live editing | UIKit (Auto Layout) |
| [`revert`](#revert) | Live editing | Core |

Core commands should behave the same on every platform. UIKit commands depend on UIKit concepts; another platform would implement its own equivalent under the same name only if the arguments and output keep the same shape.

## Shared behavior

### Each run

- Commands run one at a time. Each run gets an event generator for the key window of the foreground active scene, created on first use and finished after the command, so no touch or key stays down between commands.
- If there is no foreground key window, the command fails with `not_ready`. If the window isn't ready for interaction (backgrounded, not rendering, presenting), Hammer fails with `not_ready`.
- Gestures wait for the app to process each event before returning.
- Commands without output return `{}`.

### Arguments

Arguments are validated against the descriptor before the command runs: unknown names, missing required ones and values of the wrong type fail with `invalid_arguments`. `integer` accepts only whole numbers, `stringList` only arrays of strings, `choice` only one of its values. Then each command checks the rules listed in its section.

### Targets

Most commands take a target, from these parameters:

| Parameter | Type | Meaning |
| --- | --- | --- |
| `ref` | string | A ref from `describe`, `hierarchy` or `inspect`, such as `e12`. |
| `identifier` | string | Accessibility identifier. |
| `label` | string | Accessibility label. |
| `value` | string | Accessibility value. |
| `traits` | stringList | Accessibility traits the element must all have. |
| `x`, `y` | number | A point in window points. |

Commands with a second target, `drag` and `add_constraint`, take the same parameters prefixed with `to_`.

- **One kind:** a target is a ref, a query (any of `identifier`, `label`, `value`, `traits`) or a point. Passing more than one kind, or only one of `x` and `y`, fails with `invalid_arguments`.
- **Empty:** with no target, gestures use the center of the window. Commands that need a target say so.
- **Traits:** `button`, `link`, `header`, `searchField`, `image`, `selected`, `playsSound`, `keyboardKey`, `staticText`, `summaryElement`, `notEnabled`, `updatesFrequently`, `startsMediaSession`, `adjustable`, `allowsDirectInteraction`, `causesPageTurn`, `tabBar`, `toggleButton`, `supportsZoom`. Unknown names fail with `invalid_arguments` and suggest the closest one.
- **Matching:** every query field given must equal the element's, and the element must have every trait given. Matches that activate at the same point (within 1 point), like a button and its title label, count as one. Of the rest, visible ones are preferred, then actionable ones (controls, or elements with the `button`, `link` or `adjustable` trait). If more than one is left, the command fails with `ambiguous_target`. If none match, `not_found`.
- **Touch location:** for a view, the center of its visible area. For an accessibility element that isn't a view, such as a SwiftUI one, its activation point. For a point, the point itself.
- **Visible:** a view is visible when it and every superview are not hidden, have an alpha of at least 0.01, and it is at least partly inside every clipping superview. Touching an element that isn't visible fails with `not_visible`.
- **Hittable:** a view is hittable when it is visible and a hit test at its touch location lands on it or a subview, with user interaction enabled on the way. Touching one that isn't fails with `not_hittable`.
- **Views:** commands that act on a view (`hierarchy`, `inspect`, `screenshot` and the live editing commands) resolve a point to the topmost view hit at it, and fail with `invalid_arguments` when a ref or query resolves to an accessibility element that isn't a view.

### Refs

- Refs are `e` plus a number for views and elements, and `c` plus a number for constraints. Numbers increase for the life of the agent and are never reused.
- The same object keeps its ref while it is alive. Objects are held weakly, and refs of released objects are dropped the next time `describe`, `hierarchy` or `inspect` runs.
- A ref that is unknown, of the wrong kind or whose object is gone fails with `invalid_arguments`.

### Shapes

Frames are objects in window points, rounded to a tenth of a point in `describe` and to a hundredth elsewhere:

```json
{"x": 16, "y": 120, "width": 343, "height": 44}
```

`type` fields are the runtime class name of the view or element, such as `UIButton` or `SwiftUI.AccessibilityNode`. Optional fields are left out rather than set to `null`, unless a section says otherwise.

## Screen

### describe

Returns the visible accessibility tree of the key window.

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `all` | boolean | `false` | Include visible views without accessibility information. |

The output is an array of root nodes:

```json
[
  {
    "ref": "e3",
    "type": "UIButton",
    "identifier": "sign_in",
    "label": "Sign In",
    "traits": ["button"],
    "frame": {"x": 16, "y": 600, "width": 343, "height": 50},
    "hittable": true
  }
]
```

- **Fields:** `ref`, `type`, `frame` and `hittable` are always present. `identifier`, `label` and `value` are left out when empty, `traits` when there are none and `children` when there are none.
- **Contents:** the views and accessibility elements of the window, including elements that aren't views such as SwiftUI's, back to front.
- **Filtering:** elements that aren't visible are left out. Without `all`, so are elements with no identifier, label, value or traits. Either way, a node left out is replaced by its children, so the tree only keeps the nodes that matter.

### hierarchy

Returns the view tree of the key window or of one view, including hidden views.

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| target | | window | The view to start from. |
| `depth` | integer | all | Levels of subviews to include. `0` returns only the view. Negative fails with `invalid_arguments`. |

The output is one node:

```json
{
  "ref": "e1",
  "type": "UIWindow",
  "frame": {"x": 0, "y": 0, "width": 393, "height": 852},
  "children": [
    {"ref": "e2", "type": "UIView", "viewController": "SignInViewController", "frame": {"x": 0, "y": 0, "width": 393, "height": 852}},
    {"ref": "e7", "type": "UILabel", "identifier": "error", "frame": {"x": 16, "y": 80, "width": 343, "height": 20}, "hidden": true}
  ]
}
```

- **Fields:** `identifier` is left out when empty, `hidden` unless the view is hidden, `alpha` unless it is below 1, `viewController` unless the view is a view controller's root view, and `children` when there are none.
- **Order:** children are the view's subviews in order, back to front.

### inspect

Returns a view's properties and the constraints that lay it out.

| Parameter | Type | Meaning |
| --- | --- | --- |
| target | | The view, required. |

```json
{
  "ref": "e3",
  "type": "UILabel",
  "viewController": null,
  "frameInWindow": {"x": 16, "y": 80, "width": 343, "height": 20},
  "hasAmbiguousLayout": false,
  "properties": [
    {"name": "alpha", "type": "number", "value": 1, "settable": true, "summary": "The opacity, from 0 to 1"}
  ],
  "constraints": [
    {
      "ref": "c4",
      "description": "e3.leading == e2.leading + 16",
      "first": {"ref": "e3", "type": "UILabel"},
      "firstAttribute": "leading",
      "relation": "equal",
      "second": {"ref": "e2", "type": "UIView"},
      "secondAttribute": "leading",
      "multiplier": 1,
      "constant": 16,
      "priority": 1000,
      "active": true,
      "fromAutoresizingMask": false
    }
  ],
  "superview": {"ref": "e2", "type": "UIView"},
  "subviews": []
}
```

- **Properties:** the view's supported [properties](#properties), in a fixed order, with their current value encoded as their type.
- **Constraints:** every constraint affecting the view's horizontal and vertical layout, without duplicates. `first` and `second` are a view (`ref`, `type`) or a layout guide (`ref` of its owning view, `type`, `identifier`), and are left out when missing. `secondAttribute` is left out when there is no second item. `identifier` is the constraint's own, when it has one. `description` reads like code: `first.attribute relation second.attribute * multiplier + constant @priority`, leaving out a multiplier of 1, a constant of 0 and a priority of 1000.
- **Fields:** `viewController` and `superview` are `null` when missing.

### screenshot

Captures the screen, or the area of one view, as a PNG [image](http-api.md#post-commandsname).

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| target | | screen | The view to capture. |
| `scale` | number | `1` | Pixels per point, above 0 and up to 4. |

- **Contents:** every window of the foreground scene that isn't hidden, drawn in window level order, so alerts and keyboards show. A view's capture is the area of its frame inside the window, including whatever covers it.
- **Errors:** a scale out of range, or a view whose frame is empty or outside the window, fails with `invalid_arguments`.

## Gestures

Gestures act on a target, or on the center of the window without one. They fail with `not_found`, `ambiguous_target`, `not_visible` or `not_hittable` when the target can't be touched.

### tap

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| target | | center | What to tap. |
| `count` | integer | `1` | Number of taps, `2` for a double tap. Below 1 fails with `invalid_arguments`. |

### long_press

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| target | | center | What to press. |
| `duration` | number | `2` | Seconds to hold. |

### swipe

Moves a finger from the target in a direction.

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| target | | center | Where the swipe starts. |
| `direction` | `up`, `down`, `left`, `right` | required | The direction the finger moves. Swiping up scrolls content down. |
| `distance` | number | `200` | Points the finger moves. |
| `duration` | number | `0.2` | Seconds the swipe takes. |

### edge_swipe

Swipes from the edge opposite the direction, such as from the left edge for `right`. The touch is marked as an edge touch, so screen edge gesture recognizers handle it, like a navigation controller's swipe back.

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `direction` | `up`, `down`, `left`, `right` | required | The direction the finger moves. |
| `distance` | number | `200` | Points the finger moves. |
| `duration` | number | `0.2` | Seconds the swipe takes. |

### drag

Touches the start, moves to the end and lifts.

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| target | | required | Where the drag starts. |
| `to_` target | | required | Where the drag ends. |
| `duration` | number | `0.5` | Seconds the drag takes. |

Missing either target fails with `invalid_arguments`.

## Keyboard

Keys are hardware keyboard events sent to the first responder.

### type_text

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `text` | string | required | The text to type. |
| target | | none | A field to tap first, to focus it. |

Each character is mapped to its closest key, holding shift for uppercase letters and shifted symbols. A character with no key fails with `invalid_arguments`.

### press_key

| Parameter | Type | Meaning |
| --- | --- | --- |
| `key` | string, required | A key name, or a single character. |

Key names are the cases of [KeyboardKey](../../Sources/Hammer/EventGenerator/EventGenerator+Keyboard/KeyboardKey.swift), such as `returnOrEnter`, `escape`, `deleteOrBackspace`, `tab`, `spacebar` and `arrowUp`. A name is tried before a character, so `a` is the character but `tab` is the key. Anything else fails with `invalid_arguments` and suggests the closest name. Another platform would map these names to its own keys.

## Waiting

### wait_for

Waits until an element reaches a state, checking every frame.

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| query | | required | `identifier`, `label`, `value` and `traits`. Refs and points fail with `invalid_arguments`, since the element may not exist yet. |
| `condition` | `exists`, `visible`, `hittable`, `gone` | `hittable` | The state to wait for. `gone` means no element matches. |
| `timeout` | number | `10` | Seconds to wait. |

On timeout it fails with `timed_out`, and the message says whether the element exists at that moment.

### wait_for_idle

Waits until the key window has no running animations.

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `timeout` | number | `10` | Seconds to wait. |

On timeout it fails with `timed_out`.

## Live editing

Changes are recorded so `revert` can undo them. Only the first change to each property of each object is recorded, so reverting restores the original value, not the one before the last change. After each change the window lays out again, so the next command sees its effect. The app keeps the changes until `revert` or a relaunch.

### set_property

| Parameter | Type | Meaning |
| --- | --- | --- |
| target | | The view, required. |
| `property` | string, required | A property name as `inspect` lists it. |
| `to` | json, required | The new value, encoded as the property's type. |

```json
{"property": "alpha", "value": 0.5, "previous": 1}
```

`value` is read back after the change, so it shows what the view actually took. A property the view doesn't have fails with `invalid_arguments` and suggests the closest name. So does a read only property, or a value that isn't of the property's type.

### set_constraint

| Parameter | Type | Meaning |
| --- | --- | --- |
| `constraint` | string, required | A constraint ref from `inspect`. |
| `constant` | number | The new constant. |
| `priority` | number | The new priority, from 1 to 1000. |
| `active` | boolean | If the constraint is active. |

Returns the constraint, in the same shape as in `inspect`.

- At least one of `constant`, `priority` and `active` is required.
- Activating a constraint whose views aren't in the same window fails with `invalid_arguments`, since UIKit would raise an exception.
- Changing the priority to or from 1000 deactivates the constraint around the change, since UIKit doesn't allow it while active.

### add_constraint

Adds and activates a constraint between a view and another view, or a constant.

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| target | | required | The first view. |
| `attribute` | layout attribute | required | The first view's attribute. |
| `relation` | `equal`, `lessThanOrEqual`, `greaterThanOrEqual` | `equal` | The relation. |
| `to_` target | | none | The second view, or none for a constant. |
| `to_attribute` | layout attribute | `attribute` | The second view's attribute. |
| `multiplier` | number | `1` | Multiplier of the second attribute. |
| `constant` | number | `0` | The constant. |
| `priority` | number | `1000` | From 1 to 1000. |

Layout attributes are `left`, `right`, `top`, `bottom`, `leading`, `trailing`, `width`, `height`, `centerX`, `centerY`, `lastBaseline`, `firstBaseline`, `leftMargin`, `rightMargin`, `topMargin`, `bottomMargin`, `leadingMargin`, `trailingMargin`, `centerXWithinMargins` and `centerYWithinMargins`.

Returns the new constraint, in the same shape as in `inspect`, with the identifier `hammer-agent`. The view's `translatesAutoresizingMaskIntoConstraints` is left as is. These fail with `invalid_arguments`, before UIKit can raise an exception:

- `to_attribute` or `multiplier` without a second view.
- A constant for a position. Only `width` and `height` can be set to a constant.
- Attributes that can't be related. Sizes relate to sizes. Vertical positions relate to vertical positions. `leading`, `trailing` and their margins relate to each other and to centers, as do `left`, `right` and their margins, but the two groups can't be mixed.
- A multiplier of 0 for a position.
- Views that aren't in the same window.

### revert

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| target | | every change | The view whose changes to undo. |

```json
{"reverted": ["e3.alpha = 1", "c4 is e3.leading == e2.leading + 16 again", "c12 e3.height == 44 removed"]}
```

Undoes changes newest first and returns a summary of each. A constraint change belongs to the constraint's first view, so reverting a view undoes its property changes and the constraints changed or added for it. Changes to objects that were released are skipped.

## Properties

The properties `inspect` lists and `set_property` changes, from [ViewProperties.swift](../../Sources/HammerAgent/Editing/ViewProperties.swift). A view has the properties of every class it inherits from.

| Class | Properties |
| --- | --- |
| `UIView` | `isHidden`, `alpha`, `backgroundColor`, `tintColor`, `frame`, `bounds`, `clipsToBounds`, `isUserInteractionEnabled`, `contentMode`, `layoutMargins`, `translatesAutoresizingMaskIntoConstraints`, `intrinsicContentSize` (read only), `accessibilityIdentifier`, `cornerRadius`, `borderWidth`, `borderColor` |
| `UIControl` | `isEnabled`, `isSelected` |
| `UILabel` | `text`, `textColor`, `fontSize`, `numberOfLines`, `textAlignment`, `adjustsFontSizeToFitWidth` |
| `UIButton` | `title`, `titleColor` (both for the normal state) |
| `UITextField` | `text`, `placeholder`, `textColor` |
| `UIImageView` | `imageSize` (read only) |
| `UIStackView` | `axis`, `spacing`, `alignment`, `distribution`, `isLayoutMarginsRelativeArrangement` |
| `UIScrollView` | `contentOffset`, `contentSize`, `contentInset`, `isScrollEnabled` |
| `UISwitch` | `isOn`, `onTintColor` |

Values are encoded by type:

| Type | JSON |
| --- | --- |
| `number` | A number, rounded to a hundredth in outputs. |
| `integer` | A whole number. |
| `boolean` | `true` or `false`. |
| `string` | A string, or `null`. |
| `color` | Output as `"#RRGGBB"`, or `"#RRGGBBAA"` when not opaque, resolved for the view's traits, or `null`. Input also takes a name such as `"systemBlue"`, `"label"` or `"red"`, or `{"red": 0.2, "green": 0.4, "blue": 1, "alpha": 1}`. |
| `point` | `{"x": 0, "y": 0}` |
| `size` | `{"width": 0, "height": 0}`, or `null` for `imageSize` without an image. |
| `rect` | `{"x": 0, "y": 0, "width": 0, "height": 0}` |
| `insets` | `{"top": 0, "left": 0, "bottom": 0, "right": 0}` |
| `contentMode`, `textAlignment`, `axis`, `alignment`, `distribution` | The case name as a string, such as `"scaleAspectFit"`, `"center"` or `"vertical"`. |

Objects must have exactly the listed keys. Color names are in [ValueCodec.swift](../../Sources/HammerAgent/Editing/ValueCodec.swift).
