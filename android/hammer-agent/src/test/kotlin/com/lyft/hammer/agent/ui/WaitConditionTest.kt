package com.lyft.hammer.agent.ui

import com.lyft.hammer.agent.core.AgentError
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.catchThrowableOfType
import org.junit.Test

class WaitConditionTest {

    private val spinner = Target.Query("loading", null, null, emptyList())

    @Test
    fun isMet_noMatch_isOnlyGone() {
        val snapshot = Snapshot(listOf(window()), SCREEN)

        assertThat(WaitCondition.entries.filter { it.isMet(spinner, snapshot) }).containsExactly(WaitCondition.GONE)
    }

    @Test
    fun isMet_noWindow_isOnlyGone() {
        assertThat(WaitCondition.entries.filter { it.isMet(spinner, null) }).containsExactly(WaitCondition.GONE)
    }

    @Test
    fun isMet_hiddenMatch_existsButIsNotVisible() {
        val snapshot = Snapshot(listOf(window(element("e2", Frame(0.0, 0.0, 50.0, 50.0), identifier = "loading", visible = false))), SCREEN)

        assertThat(WaitCondition.entries.filter { it.isMet(spinner, snapshot) }).containsExactly(WaitCondition.EXISTS)
    }

    @Test
    fun isMet_coveredMatch_isVisibleButNotHittable() {
        val target = element("e2", Frame(0.0, 0.0, 50.0, 50.0), identifier = "loading")
        val overlay = element("e3", SCREEN, consumesTouches = true)
        val snapshot = Snapshot(listOf(window(target, overlay)), SCREEN)

        assertThat(WaitCondition.entries.filter { it.isMet(spinner, snapshot) })
            .containsExactly(WaitCondition.EXISTS, WaitCondition.VISIBLE)
    }

    @Test
    fun isMet_uncoveredMatch_isHittable() {
        val snapshot = Snapshot(listOf(window(element("e2", Frame(0.0, 0.0, 50.0, 50.0), identifier = "loading"))), SCREEN)

        assertThat(WaitCondition.entries.filter { it.isMet(spinner, snapshot) })
            .containsExactly(WaitCondition.EXISTS, WaitCondition.VISIBLE, WaitCondition.HITTABLE)
    }

    @Test
    fun isMet_twoVisibleMatches_isAmbiguousForHittable() {
        val first = element("e2", Frame(0.0, 0.0, 50.0, 50.0), identifier = "loading")
        val second = element("e3", Frame(0.0, 100.0, 50.0, 50.0), identifier = "loading")
        val snapshot = Snapshot(listOf(window(first, second)), SCREEN)

        val error = catchThrowableOfType({ WaitCondition.HITTABLE.isMet(spinner, snapshot) }, AgentError::class.java)

        assertThat(error.code).isEqualTo("ambiguous_target")
    }

    @Test
    fun parse_noCondition_isHittable() {
        assertThat(WaitCondition.parse(null)).isEqualTo(WaitCondition.HITTABLE)
    }

    @Test
    fun query_ref_isInvalid() {
        val error = catchThrowableOfType({ WaitCondition.query(Target.Ref("e2")) }, AgentError::class.java)

        assertThat(error.code).isEqualTo("invalid_arguments")
        assertThat(error.message).isEqualTo("This command needs an element to look for")
    }

    @Test
    fun timedOut_exists_namesTheStateItDidNotReach() {
        val error = WaitCondition.EXISTS.timedOut(spinner, 2.0, exists = false)

        assertThat(error.code).isEqualTo("timed_out")
        assertThat(error.message).isEqualTo("The element with identifier \"loading\" was not found after 2.0 seconds, and it does not exist")
    }
}
