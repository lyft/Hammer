package com.lyft.hammer.agent.ui

import org.assertj.core.api.Assertions.assertThat
import org.junit.Test

class ReferencesTest {

    @Test
    fun ref_sameOwnerAndNode_keepsRef() {
        val references = References()
        val view = Any()

        val first = references.ref(view, null)
        val again = references.ref(view, null)

        assertThat(again).isEqualTo(first)
    }

    @Test
    fun ref_nodesOfOneOwnerAndOtherOwners_getNewNumbers() {
        val references = References()
        val composeRoot = Any()

        val refs = listOf(references.ref(composeRoot, null), references.ref(composeRoot, 7), references.ref(Any(), null))

        assertThat(refs).containsExactly("e1", "e2", "e3")
    }

    @Test
    fun assign_tree_setsEveryRef() {
        val child = element("", Frame(0.0, 0.0, 1.0, 1.0))
        val root = element("", Frame(0.0, 0.0, 1.0, 1.0), children = listOf(child))

        References().assign(listOf(root))

        assertThat(listOf(root.ref, child.ref)).containsExactly("e1", "e2")
    }
}
