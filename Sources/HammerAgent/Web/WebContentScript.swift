/// The script the agent runs in a web view's own content world, so the page's scripts can't see or change it.
///
/// It runs as the body of an async function with the arguments `operation`, `page` and `id`:
///
/// - `read` lists the page's elements, as a screen reader would group them.
/// - `locate` reads the element with the id again, or returns no element when it is gone.
/// - `focused` returns if the element with the id has the keyboard focus.
///
/// Each element gets an id that it keeps while the page is loaded. `page` names the page, so an id from a
/// page that has since been replaced, by a navigation or a reload, finds nothing.
///
/// Frames are in the page's CSS pixels from the top left of the document, so the agent can convert them
/// with the web view's zoom. Same origin frames are read too; frames from other origins can't be.
let kWebContentScript = #"""
const state = globalThis.__hammer ??= {
    page: Date.now().toString(36) + Math.random().toString(36).slice(2),
    ids: new WeakMap(),
    targets: new Map(),
    next: 1,
};

// Roles and the traits they have, matching the names of UIAccessibilityTraits
const ROLE_TRAITS = {
    button: ['button'], link: ['link'], checkbox: ['button', 'toggleButton'],
    switch: ['button', 'toggleButton'], radio: ['button'], tab: ['button'], menuitem: ['button'],
    menuitemcheckbox: ['button', 'toggleButton'], menuitemradio: ['button'], option: ['button'],
    heading: ['header'], img: ['image'], image: ['image'], searchbox: ['searchField'], textbox: [],
    combobox: [], slider: ['adjustable'], spinbutton: ['adjustable'], picker: ['button'],
};
const EDITABLE_ROLES = new Set(['textbox', 'searchbox', 'combobox']);
const SKIPPED = new Set(['script', 'style', 'noscript', 'template', 'head', 'meta', 'link', 'title']);
const BUTTON_INPUTS = new Set(['button', 'submit', 'reset', 'image']);
const PICKER_INPUTS = new Set(['date', 'time', 'datetime-local', 'month', 'week', 'color', 'file']);
const TEXT_INPUTS = new Set(['', 'text', 'email', 'number', 'password', 'tel', 'url']);

function normalize(text) {
    return (text ?? '').replace(/\s+/g, ' ').trim();
}

function idFor(target) {
    let id = state.ids.get(target.key);
    if (id === undefined) {
        id = state.next++;
        state.ids.set(target.key, id);
    }

    // Kept weakly, so the page can release removed elements
    state.targets.set(id, { key: new WeakRef(target.key), end: target.end && new WeakRef(target.end),
                            kind: target.kind, offset: target.offset });
    return id;
}

function composedChildren(node) {
    if (node.shadowRoot) {
        return node.shadowRoot.childNodes;
    }

    if (node.localName === 'slot') {
        const assigned = node.assignedNodes();
        return assigned.length ? assigned : node.childNodes;
    }

    return node.childNodes;
}

function composedParent(node) {
    return node.assignedSlot ?? node.parentNode ?? node.host ?? null;
}

function composedContains(ancestor, node) {
    for (let current = node; current; current = composedParent(current)) {
        if (current === ancestor) {
            return true;
        }
    }

    return false;
}

function isHiddenSubtree(element) {
    return element.getAttribute('aria-hidden') === 'true' || element.inert
        || (element.localName === 'input' && element.type === 'hidden');
}

function roleOf(element) {
    const explicit = (element.getAttribute('role') ?? '').trim().split(/\s+/)[0];
    if (explicit === 'presentation' || explicit === 'none') {
        return null;
    }

    if (explicit in ROLE_TRAITS) {
        return explicit;
    }

    switch (element.localName) {
    case 'a':
    case 'area':
        return element.hasAttribute('href') ? 'link' : null;
    case 'button':
    case 'summary':
        return 'button';
    case 'select':
        return 'picker';
    case 'textarea':
        return 'textbox';
    case 'img':
        return element.getAttribute('alt') === '' ? null : 'img';
    case 'h1': case 'h2': case 'h3': case 'h4': case 'h5': case 'h6':
        return 'heading';
    case 'input': {
        const type = element.type;
        if (BUTTON_INPUTS.has(type)) return 'button';
        if (type === 'checkbox') return 'checkbox';
        if (type === 'radio') return 'radio';
        if (type === 'range') return 'slider';
        if (type === 'search') return 'searchbox';
        if (PICKER_INPUTS.has(type)) return 'picker';
        return 'textbox';
    }
    }

    if (element.isContentEditable && !element.parentElement?.isContentEditable) {
        return 'textbox';
    }

    return null;
}

// The text a person sees in the node, with image descriptions
function textOf(node) {
    if (node.nodeType === Node.TEXT_NODE) {
        return node.data;
    }

    if (node.nodeType !== Node.ELEMENT_NODE || SKIPPED.has(node.localName) || isHiddenSubtree(node)) {
        return '';
    }

    const style = getComputedStyle(node);
    if (style.display === 'none') {
        return '';
    }

    if (node.localName === 'img') {
        return ' ' + (node.getAttribute('alt') ?? '') + ' ';
    }

    if (node.localName === 'br') {
        return ' ';
    }

    if (node.localName === 'input' || node.localName === 'select' || node.localName === 'textarea') {
        return ' ' + (valueOf(node, roleOf(node)) ?? '') + ' ';
    }

    const isInline = style.display.startsWith('inline') || style.display === 'contents';
    let text = isInline ? '' : ' ';
    for (const child of composedChildren(node)) {
        text += textOf(child);
    }

    return isInline ? text : text + ' ';
}

function textOfIds(element, ids) {
    const root = element.getRootNode();
    return ids.trim().split(/\s+/)
        .map((id) => root.getElementById?.(id) ?? element.ownerDocument.getElementById(id))
        .filter(Boolean).map(textOf).join(' ');
}

function nameOf(element, role) {
    const labelledBy = element.getAttribute('aria-labelledby');
    const byIds = labelledBy ? normalize(textOfIds(element, labelledBy)) : '';
    if (byIds) {
        return byIds;
    }

    const ariaLabel = normalize(element.getAttribute('aria-label'));
    if (ariaLabel) {
        return ariaLabel;
    }

    const name = element.localName;
    if (name === 'input' && BUTTON_INPUTS.has(element.type)) {
        const defaults = { submit: 'Submit', reset: 'Reset', image: 'Submit' };
        const text = element.type === 'image' ? element.alt || element.value : element.value;
        return normalize(text) || defaults[element.type] || normalize(element.title) || null;
    }

    if (name === 'input' || name === 'select' || name === 'textarea') {
        const labels = Array.from(element.labels ?? []).map(textOf).join(' ');
        return normalize(labels) || normalize(element.placeholder) || normalize(element.title) || null;
    }

    if (name === 'img') {
        return normalize(element.alt) || normalize(element.title) || null;
    }

    if (EDITABLE_ROLES.has(role)) {
        return normalize(element.title) || null;
    }

    return normalize(textOf(element)) || normalize(element.title) || null;
}

function valueOf(element, role) {
    const name = element.localName;
    if (role === 'checkbox' || role === 'switch' || role === 'radio' || role === 'menuitemcheckbox'
        || role === 'menuitemradio') {
        const checked = name === 'input' ? String(element.checked) : element.getAttribute('aria-checked');
        return checked === 'true' ? '1' : checked === 'mixed' ? '2' : '0';
    }

    if (name === 'select') {
        return normalize(Array.from(element.selectedOptions).map((option) => option.label).join(', '))
            || null;
    }

    if (name === 'input' && element.type === 'password') {
        return element.value ? '•'.repeat(element.value.length) : null;
    }

    if ((name === 'input' && !BUTTON_INPUTS.has(element.type)) || name === 'textarea') {
        return element.value || null;
    }

    const valueText = normalize(element.getAttribute('aria-valuetext'))
        || normalize(element.getAttribute('aria-valuenow'));
    if (valueText) {
        return valueText;
    }

    if (role === 'textbox' && element.isContentEditable) {
        return normalize(textOf(element)) || null;
    }

    return null;
}

function traitsOf(element, role) {
    const traits = [...ROLE_TRAITS[role]];
    const isOn = (name) => element.getAttribute(name) === 'true';
    if ((element.localName === 'input' && element.checked && (role === 'checkbox' || role === 'radio'))
        || isOn('aria-checked') || isOn('aria-selected') || isOn('aria-pressed')) {
        traits.push('selected');
    }

    if (element.matches(':disabled') || isOn('aria-disabled')) {
        traits.push('notEnabled');
    }

    return traits;
}

// The rectangle and the point to touch it at, in the main frame's viewport, or null if not rendered
function geometry(target, offset, clip) {
    let rect;
    let lines;
    let hitRoot;
    let owner;
    if (target.kind === 'text') {
        const range = target.key.ownerDocument.createRange();
        range.setStartBefore(target.key);
        range.setEndAfter(target.end);
        rect = range.getBoundingClientRect();
        lines = range.getClientRects();
        owner = target.key.parentElement ?? target.key.parentNode?.host ?? null;
        hitRoot = target.key.getRootNode();
    } else {
        rect = target.key.getBoundingClientRect();
        lines = target.key.getClientRects();
        owner = target.key;
        hitRoot = owner.getRootNode();
    }

    if (!owner || (rect.width <= 0 && rect.height <= 0)) {
        return null;
    }

    const style = getComputedStyle(owner);
    const rendered = style.visibility !== 'hidden' && style.visibility !== 'collapse';
    const frame = {
        x: rect.left + offset.x, y: rect.top + offset.y, width: rect.width, height: rect.height,
    };
    const viewport = window.visualViewport;
    const screen = intersect(viewport
        ? { x: viewport.offsetLeft, y: viewport.offsetTop,
            width: viewport.width, height: viewport.height }
        : { x: 0, y: 0, width: innerWidth, height: innerHeight }, clip);
    const visibleArea = screen && intersect(frame, screen);
    const visible = rendered && visibleArea !== null;
    // Text that wraps, such as a link in a paragraph, is touched on its first visible line, since the
    // middle of its bounding box can be on other text
    const visibleLines = screen ? Array.from(lines)
        .map((line) => intersect({ x: line.left + offset.x, y: line.top + offset.y, width: line.width,
                                   height: line.height }, screen))
        .filter(Boolean) : [];
    const area = visibleLines[0] ?? visibleArea ?? frame;
    const hit = { x: area.x + area.width / 2, y: area.y + area.height / 2 };

    let hittable = false;
    if (visible) {
        const finder = hitRoot.elementFromPoint ? hitRoot : owner.ownerDocument;
        const topmost = finder.elementFromPoint(hit.x - offset.x, hit.y - offset.y);
        hittable = topmost !== null && composedContains(owner, topmost)
            && getComputedStyle(owner).pointerEvents !== 'none';
    }

    return { frame, hit, visible, hittable };
}

function intersect(a, b) {
    if (!b) {
        return a;
    }

    const x = Math.max(a.x, b.x);
    const y = Math.max(a.y, b.y);
    const right = Math.min(a.x + a.width, b.x + b.width);
    const bottom = Math.min(a.y + a.height, b.y + b.height);
    return right > x && bottom > y ? { x, y, width: right - x, height: bottom - y } : null;
}

function output(target, info, offset, clip) {
    const shape = geometry(target, offset, clip);
    if (!shape) {
        return null;
    }

    return {
        id: idFor(target), type: info.type, identifier: info.identifier || null,
        label: info.label || null,
        value: info.value ?? null, traits: info.traits, editable: info.editable ?? false,
        x: shape.frame.x + scrollX, y: shape.frame.y + scrollY, width: shape.frame.width,
        height: shape.frame.height, hitX: shape.hit.x + scrollX, hitY: shape.hit.y + scrollY,
        visible: shape.visible, hittable: shape.hittable,
    };
}

function describeElement(element, role) {
    return {
        type: element.localName, identifier: element.id, label: nameOf(element, role),
        value: valueOf(element, role), traits: traitsOf(element, role),
        editable: EDITABLE_ROLES.has(role),
    };
}

// Reads the elements under the node into `results`. Runs of text in inline elements are joined into
// one static text, the way VoiceOver reads a paragraph, while elements with a role stand on their own.
function read(root, frame, results) {
    let run = null;

    function flush() {
        if (run) {
            const label = normalize(run.text);
            if (label) {
                const target = { kind: 'text', key: run.start, end: run.end, offset: frame.offset };
                const element = output(target, { type: 'text', label, traits: ['staticText'] },
                                       frame.offset, frame.clip);
                element && results.push(element);
            }
        }

        run = null;
    }

    function visit(node) {
        if (node.nodeType === Node.TEXT_NODE) {
            if (node.data.trim()) {
                run ??= { text: '', start: node, end: node };
                run.text += node.data;
                run.end = node;
            } else if (run) {
                run.text += ' ';
            }

            return;
        }

        if (node.nodeType !== Node.ELEMENT_NODE || SKIPPED.has(node.localName) || isHiddenSubtree(node)) {
            return;
        }

        const style = getComputedStyle(node);
        if (style.display === 'none') {
            return;
        }

        if (node.localName === 'br') {
            run && (run.text += ' ');
            return;
        }

        if (node.localName === 'iframe' || node.localName === 'frame') {
            flush();
            readFrame(node, style, frame, results);
            return;
        }

        const role = roleOf(node);
        if (role === 'heading') {
            flush();
            readHeading(node, frame, results);
            return;
        }

        if (role) {
            flush();
            const element = output({ kind: 'element', key: node, offset: frame.offset },
                                   describeElement(node, role), frame.offset, frame.clip);
            element && results.push(element);
            return;
        }

        const isInline = style.display.startsWith('inline') || style.display === 'contents';
        if (!isInline) {
            flush();
        }

        for (const child of composedChildren(node)) {
            visit(child);
        }

        if (!isInline) {
            flush();
        }
    }

    for (const child of composedChildren(root)) {
        visit(child);
    }

    flush();
}

// A heading whose text is all one link or button is read as that element with the header trait
function readHeading(heading, frame, results) {
    const inner = [];
    read(heading, frame, inner);
    const label = nameOf(heading, 'heading');
    const actionable = inner.filter((element) => !element.traits.includes('staticText'));
    if (actionable.length === 1 && actionable[0].label === label) {
        actionable[0].traits.push('header');
        results.push(actionable[0]);
        return;
    }

    const element = output({ kind: 'element', key: heading, offset: frame.offset },
                           describeElement(heading, 'heading'), frame.offset, frame.clip);
    element && results.push(element);
    results.push(...actionable);
}

function readFrame(element, style, frame, results) {
    let document;
    try {
        document = element.contentDocument;
    } catch {
        return;
    }

    if (!document?.documentElement) {
        return;
    }

    const rect = element.getBoundingClientRect();
    const offset = {
        x: frame.offset.x + rect.left + element.clientLeft + parseFloat(style.paddingLeft),
        y: frame.offset.y + rect.top + element.clientTop + parseFloat(style.paddingTop),
    };
    const box = { x: offset.x, y: offset.y, width: element.clientWidth, height: element.clientHeight };
    const clip = frame.clip ? intersect(frame.clip, box) ?? { x: 0, y: 0, width: 0, height: 0 } : box;
    read(document.documentElement, { offset, clip }, results);
}

function locate(id) {
    const stored = state.targets.get(id);
    const key = stored?.key.deref();
    const end = stored?.end?.deref();
    if (!key || !key.isConnected || (stored.end && (!end || !end.isConnected))) {
        state.targets.delete(id);
        return null;
    }

    // Reads the frame the element is in again, since it may have moved
    const results = [];
    read(document.documentElement, { offset: { x: 0, y: 0 }, clip: null }, results);
    return results.find((element) => element.id === id) ?? null;
}

function deepActiveElement() {
    let active = document.activeElement;
    while (active) {
        const inner = active.shadowRoot?.activeElement
            ?? (active.localName === 'iframe' ? safeFrameActiveElement(active) : null);
        if (!inner) {
            break;
        }

        active = inner;
    }

    return active;
}

function safeFrameActiveElement(frame) {
    try {
        return frame.contentDocument?.activeElement ?? null;
    } catch {
        return null;
    }
}

switch (operation) {
case 'read': {
    for (const [id, stored] of state.targets) {
        if (!stored.key.deref()) {
            state.targets.delete(id);
        }
    }

    const results = [];
    read(document.documentElement, { offset: { x: 0, y: 0 }, clip: null }, results);
    return JSON.stringify({ page: state.page, elements: results });
}
case 'locate': {
    const element = page === state.page ? locate(id) : null;
    return JSON.stringify({ page: state.page, elements: element ? [element] : [] });
}
case 'focused': {
    const key = page === state.page ? state.targets.get(id)?.key.deref() : null;
    const active = deepActiveElement();
    return JSON.stringify(Boolean(key && active && composedContains(key, active)));
}
}

return JSON.stringify(null);
"""#
