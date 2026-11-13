package com.lyft.hammer.agent.ui

import com.lyft.hammer.agent.JsonValue
import com.lyft.hammer.agent.core.json
import com.lyft.hammer.agent.core.jsonObject

/**
 * The output of `describe`: visible elements only, and without `all` only those with accessibility
 * information or content the agent can't read. An element left out is replaced by its children.
 */
internal object DescribeOutput {

    private const val FRAME_DECIMALS = 1

    fun json(snapshot: Snapshot, all: Boolean): JsonValue.Array = JsonValue.Array(nodes(snapshot.roots, all))

    private fun nodes(elements: List<Element>, all: Boolean): List<JsonValue.Object> = elements.flatMap { element ->
        val children = nodes(element.children, all)
        when {
            !element.visible -> emptyList()
            all || element.hasAccessibilityInfo || element.needsSystemRead -> listOf(node(element, children))
            else -> children
        }
    }

    private fun node(element: Element, children: List<JsonValue.Object>): JsonValue.Object = jsonObject(
        "ref" to element.ref.json,
        "type" to element.type.json,
        "identifier" to element.identifier?.takeIf { it.isNotEmpty() }?.json,
        "label" to element.label?.takeIf { it.isNotEmpty() }?.json,
        "value" to element.value?.takeIf { it.isNotEmpty() }?.json,
        "traits" to element.traits.takeIf { it.isNotEmpty() }?.let { traits ->
            JsonValue.Array(Traits.ALL.filter { it in traits }.map { it.json })
        },
        "frame" to element.frame.toJson(FRAME_DECIMALS),
        "hittable" to element.hittable.json,
        "needsSystemRead" to element.needsSystemRead.takeIf { it }?.json,
        "children" to children.takeIf { it.isNotEmpty() }?.let { JsonValue.Array(it) },
    )
}
