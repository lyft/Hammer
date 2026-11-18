package com.lyft.hammer.agent.ui

/**
 * The elements of every foreground window, back to front, as one read of the screen. Building it
 * works out which elements touches reach.
 *
 * @property windowFrame the frontmost window's frame, whose center gestures use without a target.
 * @property density the pixels per dp, to turn frames back into screen pixels.
 * @property touches how each of [roots]' windows takes touches.
 */
internal class Snapshot(
    val roots: List<Element>,
    val windowFrame: Frame,
    val density: Double = 1.0,
    val touches: List<WindowTouch> = roots.map { WindowTouch(it.frame) },
) {

    /** Every element in drawing order: parents before children, back to front. */
    val elements: List<Element>
    private val parents = HashMap<Element, Element>()

    /** Each window's elements in drawing order, by window. */
    private val windowElements: List<List<Element>>

    init {
        require(touches.size == roots.size) { "Every window needs its touch mode" }
        val flat = mutableListOf<Element>()
        fun visit(element: Element, parent: Element?, into: MutableList<Element>) {
            flat += element
            into += element
            parent?.let { parents[element] = it }
            element.children.forEach { visit(it, element, into) }
        }
        windowElements = roots.map { root -> mutableListOf<Element>().also { visit(root, null, it) } }
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

    /**
     * The frontmost element that stops touches at [point], in the window the touch goes to. A modal
     * window's root takes the touches outside its frame.
     */
    fun receiver(point: Point): Element? {
        val window = touchedWindow(touches, point) ?: return null
        return windowElements[window].lastOrNull { it.visible && it.consumesTouches && point in it.frame } ?: roots[window]
    }

    private fun isAncestor(candidate: Element, of: Element): Boolean {
        var current = parents[of]
        while (current != null) {
            if (current === candidate) return true
            current = parents[current]
        }
        return false
    }
}
