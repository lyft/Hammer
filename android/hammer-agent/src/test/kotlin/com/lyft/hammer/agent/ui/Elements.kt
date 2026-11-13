package com.lyft.hammer.agent.ui

internal fun element(
    ref: String,
    frame: Frame,
    identifier: String? = null,
    label: String? = null,
    value: String? = null,
    traits: Set<String> = emptySet(),
    visible: Boolean = true,
    consumesTouches: Boolean = false,
    children: List<Element> = emptyList(),
    needsSystemRead: Boolean = false,
    accessibilityClass: String? = null,
) = Element(
    owner = Any(),
    nodeId = null,
    type = "android.view.View",
    identifier = identifier,
    label = label,
    value = value,
    traits = traits,
    frame = frame,
    visible = visible,
    consumesTouches = consumesTouches,
    children = children,
    needsSystemRead = needsSystemRead,
    accessibilityClass = accessibilityClass,
).also { it.ref = ref }

internal val SCREEN = Frame(0.0, 0.0, 400.0, 800.0)

internal fun window(vararg children: Element) =
    element("e1", SCREEN, consumesTouches = true, children = children.toList())
