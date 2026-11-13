package com.lyft.hammer.system

import android.app.UiAutomation
import android.os.SystemClock
import android.view.InputDevice
import android.view.KeyCharacterMap
import android.view.KeyEvent
import android.view.MotionEvent
import com.lyft.hammer.agent.AgentError
import com.lyft.hammer.agent.AgentErrorCode
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext
import kotlin.math.max

/**
 * Sends touches and keys through the input system, like a finger and a keyboard, so they reach whichever window
 * is on top, including system UI. Each event is delivered before the call returns.
 */
internal class InputInjector(private val automation: UiAutomation) {

    suspend fun tap(point: Point, count: Int) {
        repeat(count) { index ->
            if (index > 0) delay(BETWEEN_TAPS_MILLIS)
            gesture(listOf(point)) { delay(TAP_HOLD_MILLIS) }
        }
    }

    suspend fun longPress(point: Point, durationMillis: Long) {
        gesture(listOf(point)) { delay(durationMillis) }
    }

    /** Moves one finger per point of [from] to the same point of [to] over [durationMillis], for swipes and pinches. */
    suspend fun drag(from: List<Point>, to: List<Point>, durationMillis: Long) {
        val steps = max(MIN_MOVES, (durationMillis / MOVE_INTERVAL_MILLIS).toInt())
        gesture(from) { fingers ->
            for (step in 1..steps) {
                delay(durationMillis / steps)
                val fraction = step.toDouble() / steps
                fingers.move(from.zip(to) { start, end -> Point(start.x + (end.x - start.x) * fraction, start.y + (end.y - start.y) * fraction) })
            }
        }
    }

    fun pressKey(name: String) {
        val code = KeyEvent.keyCodeFromString(name)
        if (code == KeyEvent.KEYCODE_UNKNOWN) throw AgentError("Unknown key $name", AgentErrorCode.INVALID_ARGUMENTS)
        val time = SystemClock.uptimeMillis()
        inject(KeyEvent(time, time, KeyEvent.ACTION_DOWN, code, 0))
        inject(KeyEvent(time, SystemClock.uptimeMillis(), KeyEvent.ACTION_UP, code, 0))
    }

    /** Types [text] as key presses, which only covers the characters of a keyboard's key map. */
    fun typeKeys(text: String) {
        val keyMap = KeyCharacterMap.load(KeyCharacterMap.VIRTUAL_KEYBOARD)
        val events = keyMap.getEvents(text.toCharArray()) ?: throw AgentError(
            "No keys type \"$text\"",
            AgentErrorCode.INVALID_ARGUMENTS,
            "Focus a text field first, which takes any text",
        )
        events.forEach { inject(KeyEvent.changeTimeRepeat(it, SystemClock.uptimeMillis(), 0)) }
    }

    /**
     * Puts a finger down at each of [start], runs [body], then lifts them. A gesture cut short by an error or
     * cancellation is cancelled, so no view stays pressed.
     */
    private suspend fun gesture(start: List<Point>, body: suspend (Fingers) -> Unit) {
        val fingers = Fingers(start)
        fingers.down()
        try {
            body(fingers)
        } catch (error: Throwable) {
            withContext(NonCancellable) { fingers.cancel() }
            throw error
        }
        fingers.up()
    }

    private inner class Fingers(private var points: List<Point>) {
        private val downTime = SystemClock.uptimeMillis()

        fun down() {
            send(MotionEvent.ACTION_DOWN, points.take(1))
            if (points.size > 1) send(pointer(MotionEvent.ACTION_POINTER_DOWN), points)
        }

        fun move(to: List<Point>) {
            points = to
            send(MotionEvent.ACTION_MOVE, points)
        }

        fun up() {
            if (points.size > 1) send(pointer(MotionEvent.ACTION_POINTER_UP), points)
            send(MotionEvent.ACTION_UP, points.take(1))
        }

        fun cancel() = send(MotionEvent.ACTION_CANCEL, points)

        private fun pointer(action: Int) = action or (1 shl MotionEvent.ACTION_POINTER_INDEX_SHIFT)

        private fun send(action: Int, at: List<Point>) {
            val properties = Array(at.size) { index ->
                MotionEvent.PointerProperties().apply {
                    id = index
                    toolType = MotionEvent.TOOL_TYPE_FINGER
                }
            }
            val coordinates = Array(at.size) { index ->
                MotionEvent.PointerCoords().apply {
                    x = at[index].x.toFloat()
                    y = at[index].y.toFloat()
                    pressure = 1f
                    size = 1f
                }
            }
            val event = MotionEvent.obtain(
                downTime, SystemClock.uptimeMillis(), action, at.size, properties, coordinates,
                0, 0, 1f, 1f, 0, 0, InputDevice.SOURCE_TOUCHSCREEN, 0,
            )
            try {
                inject(event)
            } finally {
                event.recycle()
            }
        }
    }

    private fun inject(event: android.view.InputEvent) {
        if (!automation.injectInputEvent(event, true)) {
            throw AgentError("Android refused the input event", AgentErrorCode.FAILED)
        }
    }

    private companion object {
        const val TAP_HOLD_MILLIS = 50L
        const val BETWEEN_TAPS_MILLIS = 80L
        const val MOVE_INTERVAL_MILLIS = 10L
        const val MIN_MOVES = 2
    }
}
