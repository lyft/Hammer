package com.lyft.hammer.agent.ui

import com.google.gson.JsonArray
import com.google.gson.JsonObject
import com.lyft.hammer.agent.core.JsonArrays

/**
 * The output of `describe`: visible elements only, and without `all` only those with accessibility
 * information. An element left out is replaced by its children.
 */
internal object DescribeOutput {

    private const val FRAME_DECIMALS = 1

    fun json(snapshot: Snapshot, all: Boolean): JsonArray = JsonArrays.of(nodes(snapshot.roots, all))

    private fun nodes(elements: List<Element>, all: Boolean): List<JsonObject> = elements.flatMap { element ->
        val children = nodes(element.children, all)
        when {
            !element.visible -> emptyList()
            all || element.hasAccessibilityInfo -> listOf(node(element, children))
            else -> children
        }
    }

    private fun node(element: Element, children: List<JsonObject>): JsonObject = JsonObject().apply {
        addProperty("ref", element.ref)
        addProperty("type", element.type)
        element.identifier?.takeIf { it.isNotEmpty() }?.let { addProperty("identifier", it) }
        element.label?.takeIf { it.isNotEmpty() }?.let { addProperty("label", it) }
        element.value?.takeIf { it.isNotEmpty() }?.let { addProperty("value", it) }
        if (element.traits.isNotEmpty()) {
            add("traits", JsonArray().also { array -> Traits.ALL.filter { it in element.traits }.forEach(array::add) })
        }
        add("frame", element.frame.toJson(FRAME_DECIMALS))
        addProperty("hittable", element.hittable)
        if (children.isNotEmpty()) add("children", JsonArrays.of(children))
    }
}
