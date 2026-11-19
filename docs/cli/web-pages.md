# Web pages

The agent reads the pages in the app's `WKWebView`s, so `describe`, `tap`, `type_text`, `wait_for` and the other commands work on web content the same way they work on views. The app doesn't need to change. A web view's accessibility elements live in WebKit's web content process, where the agent can't reach them, so it reads the page itself with a script instead.

```bash
hammer describe
hammer tap --label "Sign In" --traits button
hammer type-text --identifier email --text person@example.com
```

`describe` lists a page's elements as children of its `WKWebView`:

```json
{"ref": "e8", "type": "WKWebView", "frame": {"x": 0, "y": 0, "width": 402, "height": 874}, "hittable": true, "children": [
  {"ref": "w1", "type": "h1", "label": "Welcome", "traits": ["header"], "frame": {"x": 8, "y": 21.4, "width": 386, "height": 37}, "hittable": true},
  {"ref": "w2", "type": "input", "identifier": "email", "label": "Email", "frame": {"x": 8, "y": 90, "width": 200, "height": 24}, "hittable": true},
  {"ref": "w3", "type": "button", "label": "Sign In", "traits": ["button"], "frame": {"x": 8, "y": 122, "width": 64, "height": 24}, "hittable": true}
]}
```

## Elements

- **What is listed:** links, buttons, form fields, headings, images with alt text, and runs of text. A paragraph is one static text, even when parts of it are bold, the way VoiceOver reads it. A link or button inside it is listed on its own. A heading that is all one link is listed as that link, with the `header` trait.
- **Type:** the HTML tag, such as `button` or `input`, or `text` for text.
- **Identifier:** the element's `id`.
- **Label:** the accessible name: `aria-labelledby`, `aria-label`, a field's `<label>`, then its placeholder, an image's `alt`, or the element's text.
- **Value:** a field's text, with a password masked, a checkbox's or radio button's `1` or `0`, or a select's chosen option.
- **Traits:** `button`, `link`, `header`, `image`, `staticText`, `searchField`, `adjustable` and `toggleButton` by role, plus `selected` when checked, selected or pressed, and `notEnabled` when disabled. ARIA roles override the tag's.
- **Left out:** elements that are hidden, `aria-hidden` or inert, and elements off screen. Swipe to scroll them into view, as for views.
- **Frames:** window points, like views, after the page's zoom and scrolling.
- **Hittable:** the element is the topmost one at its visible center, both in the page and in the app, so a native view covering the web view makes it not hittable.

## Refs

Web elements have refs that start with `w`, such as `w3`. A `w` ref keeps working while the page is loaded: the agent finds the element again where it is now, so it still works after the page scrolls or the element's text changes. It fails with `not_found` once the element is removed or the web view loads another page. Then run `describe` again.

Web refs only work with commands that send touches or keys. `inspect`, `set_property` and the other editing commands take views, so they reject a `w` ref. Target the `WKWebView` instead.

## Queries

A query that matches no view or accessibility element is looked for in the web pages, so `--label`, `--identifier`, `--value` and `--traits` find web elements too. As for views, visible matches come first, then buttons and links, and several matches fail with `ambiguous_target`.

## Typing

`type_text` with a target taps the field, then waits up to 3 seconds for the page to give it the focus before it types, since the page takes the focus apart from the app. It fails with `timed_out` if the field never takes it.

## What it can't reach

- **Frames from another origin:** the agent reads same-origin `<iframe>`s, but browsers keep pages from reading frames from other origins. Tap those by point.
- **Closed shadow roots:** open shadow roots are read, closed ones can't be.
- **Pages outside the app:** `SFSafariViewController`, `ASWebAuthenticationSession` and Safari show their pages in another process. Use [`--system`](system-ui.md) in the simulator.

## Privacy

The script runs in its own content world, so the page's scripts can't see or change it. It only reads what `describe` shows and finds the elements that commands act on. It doesn't run JavaScript that clients send.
