package com.lyft.hammer.agent.ui

import java.util.WeakHashMap

/**
 * Hands out refs such as `e12`. The same view or semantics node keeps its ref while it is alive, and
 * numbers are never reused. Owners are held weakly, so released views drop their refs.
 */
internal class References {

    private val refs = WeakHashMap<Any, MutableMap<Int?, String>>()
    private var next = 1

    @Synchronized
    fun ref(owner: Any, nodeId: Int?): String =
        refs.getOrPut(owner) { HashMap() }.getOrPut(nodeId) { "e${next++}" }

    /** Assigns a ref to every element of [roots]. */
    fun assign(roots: List<Element>) {
        roots.forEach { root ->
            root.ref = ref(root.owner, root.nodeId)
            assign(root.children)
        }
    }
}
