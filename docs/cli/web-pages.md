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

- **What is listed:** links, buttons, form fields, headings, images, and runs of text. A paragraph is one static text, even when parts of it are bold, the way VoiceOver reads it. A link or button inside it is listed on its own and ends the text before it. A heading that is all one link is listed as that link, with the `header` trait. The text of a `<label>` that names a field is the field's label, so it isn't listed again as text, and `--label Email` finds the field.
- **Type:** the HTML tag, such as `button` or `input`, or `text` for text.
- **Identifier:** the element's `id`.
- **Label:** the accessible name: `aria-labelledby`, `aria-label`, a field's `<label>`, then its placeholder, an image's `alt`, or the element's text.
- **Value:** a field's text, with a password masked, a checkbox's or radio button's `1` or `0`, or a select's chosen option.
- **Traits:** `button`, `link`, `header`, `image`, `staticText`, `searchField`, `adjustable` and `toggleButton` by role, plus `selected` when checked, selected or pressed, and `notEnabled` when disabled. ARIA roles override the tag's, and roles that aren't ARIA roles are ignored.
- **Left out:** elements that are hidden, fully transparent (`opacity: 0`), `aria-hidden` or inert, images with an empty `alt`, which marks them as decoration, and elements off screen. Swipe to scroll them into view, as for views.
- **Frames:** window points, like views, after the page's zoom and scrolling.
- **Touch point:** the center of the element's first visible line, so a link that wraps in a paragraph is touched on its text, not on the text around it.
- **Hittable:** the element is the topmost one at its touch point, both in the page and in the app, so a transparent layer of the page or a native view covering the web view makes it not hittable.
- **Pages that can't be read:** when a page doesn't answer within 5 seconds, such as one stuck in a script, the `WKWebView` node has a `pageError` that says why, so it doesn't look like an empty page. A web view whose last read still runs reports that too, rather than queueing another read behind it.
- **Scrolling:** a read waits up to 3 seconds for the web view to stop scrolling, such as after a swipe, since the page reports where it was scrolled to with a delay, and a touch while it decelerates only stops it. Fixed and sticky elements are where the page says once it stops.

## Refs

Web elements have refs that start with `w`, such as `w3`. A `w` ref keeps working while the page is loaded: the agent finds the element again where it is now, so it still works after the page scrolls or the element's text changes. It fails with `not_found` once the element is removed or the web view loads another page. Then run `describe` again.

Web refs only work with commands that send touches or keys. `inspect`, `set_property` and the other editing commands take views, so they reject a `w` ref. Target the `WKWebView` instead.

## Queries

Queries find web elements too, so `--label`, `--identifier`, `--value` and `--traits` work on pages. A visible view or accessibility element that matches comes first, then a visible web element, so a hidden view with the same label doesn't hide a page's button. Among web elements, visible ones come first, then the ones that act, such as buttons, links and fields, then the rest before text. Several matches left fail with `ambiguous_target`.

`wait_for` checks views every frame and pages every 150 milliseconds, since reading a page takes a call to the web content process. A page that can't be read never counts as `gone`.

## Typing

`type_text` with a target taps the field, then waits up to 3 seconds for the page to give it the focus before it types, since the page takes the focus apart from the app. It fails with `timed_out` if the field never takes it.

## What it can't reach

- **Frames from another origin:** the agent reads same-origin `<iframe>`s, but browsers keep pages from reading frames from other origins. Tap those by point.
- **Closed shadow roots:** open shadow roots are read, closed ones can't be.
- **Pages outside the app:** `SFSafariViewController`, `ASWebAuthenticationSession` and Safari show their pages in another process. Use [`--system`](system-ui.md) in the simulator.

## Privacy and trust

The script runs in its own content world, so the page's scripts can't see or change it. It only reads what `describe` shows and finds the elements that commands act on. It doesn't run JavaScript that clients send.

A password field's value is masked, one `•` per character, so it shows the password's length, as a secure text field does on iOS.

Everything `describe` lists from a page, such as labels, `alt` text and text, comes from the page. A page can put text there that a person doesn't see, such as text read only by screen readers. Treat it as untrusted input, and don't let an AI agent follow instructions it finds in a page's content.
