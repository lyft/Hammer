package com.lyft.hammer.system

import android.view.MotionEvent
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.runTest
import org.assertj.core.api.Assertions.assertThat
import org.junit.Test

class InputInjectorTest {

    private data class Touch(val action: Int, val points: List<Point>, val waitForDelivery: Boolean, val atMillis: Long)

    /** Touches sent with a clock in virtual time, where each touch that waits for delivery takes [deliveryMillis]. */
    private class Recorder(private val scope: TestScope, private val deliveryMillis: Long) : TouchInput {
        val touches = mutableListOf<Touch>()
        private var waitedMillis = 0L

        fun now() = scope.testScheduler.currentTime + waitedMillis

        override fun send(downTime: Long, action: Int, points: List<Point>, waitForDelivery: Boolean) {
            touches += Touch(action, points, waitForDelivery, now())
            if (waitForDelivery) waitedMillis += deliveryMillis
        }
    }

    @Test
    fun drag_deliveryTakesAFrame_liftsTheFingerWhenItsDurationEnds() = runTest {
        val recorder = Recorder(this, deliveryMillis = 40)
        val input = InputInjector(recorder, keys = {}, clock = recorder::now)

        input.drag(listOf(Point(100.0, 700.0)), listOf(Point(100.0, 100.0)), durationMillis = 600)

        val moves = recorder.touches.filter { it.action == MotionEvent.ACTION_MOVE }
        assertThat(recorder.touches.map { it.action }).containsExactly(
            MotionEvent.ACTION_DOWN, *IntArray(60) { MotionEvent.ACTION_MOVE }.toTypedArray(), MotionEvent.ACTION_UP,
        )
        assertThat(moves.map { it.atMillis }).containsExactlyElementsOf((1..60).map { 40L + it * 10 })
        assertThat(recorder.touches.last().atMillis).isEqualTo(640)
    }

    @Test
    fun drag_waitsForTheDownAndTheUpButNotForEachMove() = runTest {
        val recorder = Recorder(this, deliveryMillis = 40)
        val input = InputInjector(recorder, keys = {}, clock = recorder::now)

        input.drag(listOf(Point(100.0, 700.0)), listOf(Point(100.0, 100.0)), durationMillis = 200)

        assertThat(recorder.touches.map { it.waitForDelivery })
            .containsExactly(true, *Array(20) { false }, true)
        assertThat(recorder.touches.last().points).containsExactly(Point(100.0, 100.0))
    }
}
