package com.lyft.hammer.agent.ui

/**
 * The elements of every foreground window, back to front, as one read of the screen. Building it
 * works out which elements touches reach.
 *
 * @property windowFrame the frontmost window's frame, whose center gestures use without a target.
 * @property density the pixels per dp, to turn frames back into screen pixels.
 */
internal class Snapshot(val roots: List<Element>, val windowFrame: Frame, val density: Double = 1.0) {

    /** Every element in drawing order: parents before children, back to front. */
    val elements: List<Element>
    private val parents = HashMap<Element, Element>()

    init {
        val flat = mutableListOf<Element>()
        fun visit(element: Element, parent: Element?) {
            flat += element
            parent?.let { parents[element] = it }
            element.children.forEach { visit(it, element) }
        }
        roots.forEach { visit(it, null) }
        elements = flat
        elements.forEach { it.hittable = isHittable(it) }
    }

    fun element(ref: String): Element? = elements.firstOrNull { it.ref == ref }

    /**
     * A touch reaches an element when the frontmost element that stops touches at its location is
     * the element itself, one of its ancestors (a clickable card around a label) or one of its
     * descendants (a button inside a row).
     */
    private fun isHittable(element: Element): Boolean {
        if (!element.visible) return false
        val receiver = receiver(element.touchPoint) ?: return true
        return receiver === element || isAncestor(receiver, of = element) || isAncestor(element, of = receiver)
    }

    /** The frontmost element that stops touches at [point]. */
    fun receiver(point: Point): Element? = elements.lastOrNull { it.visible && it.consumesTouches && point in it.frame }

    private fun isAncestor(candidate: Element, of: Element): Boolean {
        var current = parents[of]
        while (current != null) {
            if (current === candidate) return true
            current = parents[current]
        }
        return false
    }
}
