package com.lyft.hammer.agent.ui

/**
 * Puts the Views a Compose root hosts, such as a map in an `AndroidView`, where Compose draws them.
 * They are children of the root's `AndroidViewsHandler` in the View tree, but Compose draws each at
 * its place in the layout, under whatever comes later. Each goes last in the deepest semantics node
 * that contains it, or on top when none does.
 */
internal object InteropPlacement {

    private const val TOLERANCE = 1.0

    fun place(nodes: List<Element>, views: List<Element>): List<Element> = views.fold(nodes) { placed, view ->
        insert(placed, view) ?: (placed + view)
    }

    private fun insert(nodes: List<Element>, view: Element): List<Element>? {
        val index = nodes.indexOfLast { it.frame.encloses(view.frame) }
        if (index < 0) return null
        val node = nodes[index]
        val children = insert(node.children, view) ?: (node.children + view)
        return nodes.toMutableList().also { it[index] = node.withChildren(children) }
    }

    private fun Frame.encloses(other: Frame) = !isEmpty &&
        other.x >= x - TOLERANCE && other.y >= y - TOLERANCE &&
        other.x + other.width <= x + width + TOLERANCE && other.y + other.height <= y + height + TOLERANCE
}
