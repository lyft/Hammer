/// The script the agent runs in a web view's own content world, so the page's scripts can't see or change it.
///
/// It runs as the body of an async function with the arguments `operation`, `page`, `id` and `version`. It
/// installs its functions on the content world's global object once per page, so later calls send only
/// `kWebContentCallScript`, and returns the result of the operation:
///
/// - `read` lists the page's elements, as a screen reader would group them.
/// - `locate` reads the element with the id again, or returns no element when it is gone.
/// - `focused` returns if the element with the id has the keyboard focus, and a short description of the
///   element that has it.
/// - `ready` returns if the document has loaded, after the page renders two frames, so the web view
///   shows what the agent reads before it touches the page.
///
/// Each element gets an id that it keeps while the page is loaded. `page` names the page, so an id from a
/// page that has since been replaced, by a navigation or a reload, finds nothing.
///
/// Frames are in the page's CSS pixels from the top left of the document, so the agent can convert them
/// with the web view's zoom. Same origin frames are read too; frames from other origins can't be.
///
/// Everything it reads, such as labels and text, comes from the page, so clients must treat it as untrusted.
let kWebContentScript = #"""
const state = globalThis.__hammer ??= {
    page: Date.now().toString(36) + Math.random().toString(36).slice(2),
    ids: new WeakMap(),
    targets: new Map(),
    next: 1,
};

// Roles and the traits they have, matching the names of UIAccessibilityTraits. A Map, so a role such as
// "constructor" or "toString" isn't found on the prototype of an object.
const ROLE_TRAITS = new Map([
    ['button', ['button']], ['link', ['link']], ['checkbox', ['button', 'toggleButton']],
    ['switch', ['button', 'toggleButton']], ['radio', ['button']], ['tab', ['button']],
    ['menuitem', ['button']], ['menuitemcheckbox', ['button', 'toggleButton']], ['menuitemradio', ['button']],
    ['option', ['button']], ['heading', ['header']], ['img', ['image']], ['image', ['image']],
    ['searchbox', ['searchField']], ['textbox', []], ['combobox', []], ['slider', ['adjustable']],
    ['spinbutton', ['adjustable']],
    // Not an ARIA role, so a page can't set it: a select or a date input, which open a picker
    ['picker', ['button']],
]);
const EXPLICIT_ROLES = new Set([...ROLE_TRAITS.keys()].filter((role) => role !== 'picker'));
const EDITABLE_ROLES = new Set(['textbox', 'searchbox', 'combobox']);
const SKIPPED = new Set(['script', 'style', 'noscript', 'template', 'head', 'meta', 'link', 'title']);
const BUTTON_INPUTS = new Set(['button', 'submit', 'reset', 'image']);
const PICKER_INPUTS = new Set(['date', 'time', 'datetime-local', 'month', 'week', 'color', 'file']);

function normalize(text) {
    return (text ?? '').replace(/\s+/g, ' ').trim();
}

// Gives the target an id. Text keeps its nodes, container and label, since locate reads it on its own.
function idFor(target) {
    let id = state.ids.get(target.key);
    if (id === undefined) {
        id = state.next++;
        state.ids.set(target.key, id);
    }

    // Kept weakly, so the page can release removed elements
    state.targets.set(id, target.kind === 'text'
        ? { key: new WeakRef(target.key), nodes: target.nodes.map((node) => new WeakRef(node)),
            container: new WeakRef(target.container), label: target.label }
        : { key: new WeakRef(target.key) });
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

// If the element and what it contains can't be seen: not displayed or fully transparent
function isInvisibleSubtree(style) {
    return style.display === 'none' || Number(style.opacity) === 0;
}

function roleOf(element) {
    const explicit = (element.getAttribute('role') ?? '').trim().split(/\s+/)[0];
    if (explicit === 'presentation' || explicit === 'none') {
        return null;
    }

    if (EXPLICIT_ROLES.has(explicit)) {
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

// The text a person sees in the node, with image descriptions, leaving out `skipped`, such as the field a
// label names
function textOf(node, skipped = null) {
    if (node === skipped) {
        return '';
    }

    if (node.nodeType === Node.TEXT_NODE) {
        return node.data;
    }

    if (node.nodeType !== Node.ELEMENT_NODE || SKIPPED.has(node.localName) || isHiddenSubtree(node)) {
        return '';
    }

    const style = getComputedStyle(node);
    if (isInvisibleSubtree(style)) {
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
        text += textOf(child, skipped);
    }

    return isInline ? text : text + ' ';
}

function textOfIds(element, ids) {
    const root = element.getRootNode();
    return ids.trim().split(/\s+/)
        .map((id) => root.getElementById?.(id) ?? element.ownerDocument.getElementById(id))
        .filter(Boolean).map((node) => textOf(node)).join(' ');
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
        const labels = Array.from(element.labels ?? []).map((label) => textOf(label, element)).join(' ');
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
    const traits = [...(ROLE_TRAITS.get(role) ?? [])];
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

// If a touch at the node goes to a control inside the container rather than to the container itself,
// such as a link in a paragraph
function isInControl(node, container) {
    for (let current = node; current && current !== container; current = composedParent(current)) {
        const role = current.nodeType === Node.ELEMENT_NODE ? roleOf(current) : null;
        if (role && role !== 'heading') {
            return true;
        }
    }

    return false;
}

// The rectangle and the point to touch it at, in the main frame's viewport, or null if not rendered
function geometry(target, offset, clip) {
    let lines;
    let owner;
    if (target.kind === 'text') {
        // Only the run's own text, not the boxes of the links and buttons inside it
        lines = target.nodes.flatMap((node) => {
            const range = node.ownerDocument.createRange();
            range.selectNodeContents(node);
            return Array.from(range.getClientRects());
        });
        owner = target.key.parentElement ?? target.key.parentNode?.host ?? null;
    } else {
        lines = Array.from(target.key.getClientRects());
        owner = target.key;
    }

    lines = lines.filter((line) => line.width > 0 || line.height > 0);
    if (!owner || lines.length === 0) {
        return null;
    }

    const left = Math.min(...lines.map((line) => line.left));
    const top = Math.min(...lines.map((line) => line.top));
    const right = Math.max(...lines.map((line) => line.right));
    const bottom = Math.max(...lines.map((line) => line.bottom));
    const frame = { x: left + offset.x, y: top + offset.y, width: right - left, height: bottom - top };

    const style = getComputedStyle(owner);
    const rendered = style.visibility !== 'hidden' && style.visibility !== 'collapse';
    const viewport = window.visualViewport;
    const viewportArea = intersect(viewport
        ? { x: viewport.offsetLeft, y: viewport.offsetTop,
            width: viewport.width, height: viewport.height }
        : { x: 0, y: 0, width: innerWidth, height: innerHeight }, clip);
    const clipped = ancestorClip(owner, offset);
    const screen = clipped === undefined
        ? viewportArea : viewportArea && clipped && intersect(viewportArea, clipped);
    const visibleArea = screen && intersect(frame, screen);
    const visible = rendered && visibleArea !== null;
    // Text that wraps, such as a link in a paragraph, is touched on its first visible line, since the
    // middle of its bounding box can be on other text
    const visibleLines = screen ? lines
        .map((line) => intersect({ x: line.left + offset.x, y: line.top + offset.y, width: line.width,
                                   height: line.height }, screen))
        .filter(Boolean) : [];
    const area = visibleLines[0] ?? visibleArea ?? frame;
    const hit = { x: area.x + area.width / 2, y: area.y + area.height / 2 };

    let hittable = false;
    if (visible && style.pointerEvents !== 'none') {
        const root = target.key.getRootNode();
        const finder = root.elementFromPoint ? root : owner.ownerDocument;
        const topmost = finder.elementFromPoint(hit.x - offset.x, hit.y - offset.y);
        hittable = target.kind === 'text'
            ? topmost !== null && composedContains(target.container, topmost)
                && !isInControl(topmost, target.container)
            : topmost !== null && composedContains(owner, topmost);
    }

    return { frame, hit, visible, hittable };
}

// Computed styles of the current call, since clipping reads the same ancestors for many elements
let styles = new Map();

function styleOf(element) {
    let style = styles.get(element);
    if (!style) {
        style = getComputedStyle(element);
        styles.set(element, style);
    }

    return style;
}

// The part of the frame's document that the element's scrolling and clipping ancestors show, such as a
// carousel with overflow: hidden, in the top document's coordinates, or undefined if none clips it. An
// absolutely positioned element is only clipped by ancestors that contain it, and a fixed one by none.
function ancestorClip(element, offset) {
    let clip;
    let position = styleOf(element).position;
    for (let node = composedParent(element); node && position !== 'fixed'; node = composedParent(node)) {
        if (node.nodeType !== Node.ELEMENT_NODE) {
            continue;
        }

        // Their overflow is the viewport's, which the caller clips to already
        if (node === node.ownerDocument.documentElement || node === node.ownerDocument.body) {
            break;
        }

        const style = styleOf(node);
        if (position === 'absolute' && style.position === 'static' && style.transform === 'none') {
            continue;
        }

        if (style.overflowX !== 'visible' || style.overflowY !== 'visible') {
            const box = node.getBoundingClientRect();
            const padding = { x: box.left + node.clientLeft + offset.x,
                              y: box.top + node.clientTop + offset.y,
                              width: node.clientWidth, height: node.clientHeight };
            clip = clip === undefined ? padding : clip && intersect(clip, padding);
        }

        position = style.position;
    }

    return clip;
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

function output(target, info, frame) {
    const shape = geometry(target, frame.offset, frame.clip);
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

function textInfo(label) {
    return { type: 'text', label, traits: ['staticText'] };
}

// Reads the elements under the node into `results`. Runs of text in inline elements are joined into
// one static text, the way VoiceOver reads a paragraph, while elements with a role stand on their own.
function read(root, frame, results) {
    let run = null;
    let container = root;
    // Above zero inside a label of a control, whose text is the control's label rather than its own text
    let muted = 0;

    function flush() {
        if (run) {
            const label = normalize(run.text);
            if (label) {
                const target = { kind: 'text', key: run.nodes[0], nodes: run.nodes, container: run.container,
                                 label };
                const element = output(target, textInfo(label), frame);
                element && results.push(element);
            }
        }

        run = null;
    }

    function visit(node) {
        if (node.nodeType === Node.TEXT_NODE) {
            if (muted) {
                return;
            }

            if (node.data.trim()) {
                run ??= { text: '', nodes: [], container };
                run.text += node.data;
                run.nodes.push(node);
            } else if (run) {
                run.text += ' ';
            }

            return;
        }

        if (node.nodeType !== Node.ELEMENT_NODE || SKIPPED.has(node.localName) || isHiddenSubtree(node)) {
            return;
        }

        // One element the script can't read, such as one with an unexpected attribute, is left out rather
        // than failing the whole page
        try {
            visitElement(node);
        } catch {
            flush();
        }
    }

    function visitElement(node) {
        const style = getComputedStyle(node);
        if (isInvisibleSubtree(style)) {
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
            const element = output({ kind: 'element', key: node }, describeElement(node, role), frame);
            element && results.push(element);
            return;
        }

        const isLabelOfControl = node.localName === 'label' && node.control;
        const isInline = (style.display.startsWith('inline') || style.display === 'contents')
            && !isLabelOfControl;
        const outer = container;
        if (!isInline) {
            flush();
            container = node;
        }

        muted += isLabelOfControl ? 1 : 0;
        for (const child of composedChildren(node)) {
            visit(child);
        }

        muted -= isLabelOfControl ? 1 : 0;
        if (!isInline) {
            flush();
            container = outer;
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
    // The heading's own text is part of the heading, so its runs don't keep ids
    for (const element of inner) {
        if (element.traits.includes('staticText')) {
            state.targets.delete(element.id);
        }
    }

    if (actionable.length === 1 && actionable[0].label === label) {
        actionable[0].traits.push('header');
        results.push(actionable[0]);
        return;
    }

    const element = output({ kind: 'element', key: heading }, describeElement(heading, 'heading'), frame);
    element && results.push(element);
    results.push(...actionable);
}

// Where a frame's content is, in the main frame's viewport, and the part of it that shows
function frameBox(element, style, frame) {
    const rect = element.getBoundingClientRect();
    const offset = {
        x: frame.offset.x + rect.left + element.clientLeft + parseFloat(style.paddingLeft),
        y: frame.offset.y + rect.top + element.clientTop + parseFloat(style.paddingTop),
    };
    const box = { x: offset.x, y: offset.y, width: element.clientWidth, height: element.clientHeight };
    const clip = frame.clip ? intersect(frame.clip, box) ?? { x: 0, y: 0, width: 0, height: 0 } : box;
    return { offset, clip };
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

    read(document.documentElement, frameBox(element, style, frame), results);
}

const MAIN_FRAME = { offset: { x: 0, y: 0 }, clip: null };

// The frame of a document of this page, through the frames that contain it
function frameOf(doc) {
    if (doc === document) {
        return MAIN_FRAME;
    }

    const element = doc.defaultView?.frameElement;
    const outer = element && frameOf(element.ownerDocument);
    return outer ? frameBox(element, getComputedStyle(element), outer) : null;
}

// If the node or an element around it hides it, the way read leaves it out
function isHiddenInPage(node) {
    for (let current = node.parentNode ? node : null; current; current = composedParent(current)) {
        if (current.nodeType !== Node.ELEMENT_NODE) {
            continue;
        }

        if (isHiddenSubtree(current) || isInvisibleSubtree(getComputedStyle(current))) {
            return true;
        }
    }

    return false;
}

// Reads one element again, where it is now, without reading the rest of the page
function locate(id) {
    const stored = state.targets.get(id);
    const key = stored?.key.deref();
    const nodes = stored?.nodes?.map((node) => node.deref());
    const container = stored?.container?.deref();
    if (!key || !key.isConnected || (nodes && (!nodes.every((node) => node?.isConnected) || !container))) {
        state.targets.delete(id);
        return null;
    }

    const frame = frameOf(key.ownerDocument);
    if (!frame) {
        return null;
    }

    const target = nodes ? { kind: 'text', key, nodes, container, label: stored.label }
        : { kind: 'element', key };
    const info = nodes ? textInfo(stored.label) : describeElement(key, roleOf(key));
    const element = output(target, info, frame);
    if (element && isHiddenInPage(key)) {
        element.visible = false;
        element.hittable = false;
    }

    return element;
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

state.version = version;
state.run = (operation, page, id) => {
    styles = new Map();
    switch (operation) {
    case 'read': {
        for (const [id, stored] of state.targets) {
            if (!stored.key.deref()?.isConnected) {
                state.targets.delete(id);
            }
        }

        const results = [];
        read(document.documentElement, MAIN_FRAME, results);
        return JSON.stringify({ page: state.page, elements: results });
    }
    case 'locate': {
        const element = page === state.page ? locate(id) : null;
        return JSON.stringify({ page: state.page, elements: element ? [element] : [] });
    }
    case 'focused': {
        const key = page === state.page ? state.targets.get(id)?.key.deref() : null;
        const active = deepActiveElement();
        const focused = Boolean(key && active && composedContains(key, active));
        const description = active && active !== document.body
            ? (active.localName + (active.id ? '#' + active.id : '')).slice(0, 80) : null;
        return JSON.stringify({ focused, active: description });
    }
    case 'ready':
        return new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(() => {
            resolve(JSON.stringify(document.readyState === 'complete'));
        })));
    }

    return JSON.stringify(null);
};

return state.run(operation, page, id);
"""#

/// What the result of `kWebContentCallScript` is when the page doesn't have this version of the script yet.
let kWebContentScriptNotInstalled = "not_installed"

/// Runs the script installed on the page, so the page doesn't parse the whole script for every call.
let kWebContentCallScript = """
    const hammer = globalThis.__hammer;
    return hammer?.version === version ? hammer.run(operation, page, id) : '\(kWebContentScriptNotInstalled)';
    """
