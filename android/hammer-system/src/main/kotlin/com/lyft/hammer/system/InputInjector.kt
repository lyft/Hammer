package com.lyft.hammer.system

import android.app.UiAutomation
import android.os.SystemClock
import android.view.InputDevice
import android.view.InputEvent
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
 * is on top, including system UI. Every event but a drag's moves is delivered before the call returns.
 */
internal class InputInjector(
    private val touches: TouchInput,
    private val keys: (KeyEvent) -> Unit,
    private val clock: () -> Long = SystemClock::uptimeMillis,
) {

    constructor(automation: UiAutomation) : this(AutomationTouches(automation), { automation.injectOrFail(it, waitForDelivery = true) })

    suspend fun tap(point: Point, count: Int) {
        repeat(count) { index ->
            if (index > 0) delay(BETWEEN_TAPS_MILLIS)
            gesture(listOf(point)) { delay(TAP_HOLD_MILLIS) }
        }
    }

    suspend fun longPress(point: Point, durationMillis: Long) {
        gesture(listOf(point)) { delay(durationMillis) }
    }

    /**
     * Moves one finger per point of [from] to the same point of [to] over [durationMillis], for swipes and pinches.
     * Each move is timed from the start, and only the finger going down and lifting wait for delivery: a window
     * handles moves once a frame, so waiting for each one would stretch the drag and slow its fling.
     */
    suspend fun drag(from: List<Point>, to: List<Point>, durationMillis: Long) {
        val steps = max(MIN_MOVES, (durationMillis / MOVE_INTERVAL_MILLIS).toInt())
        gesture(from) { fingers ->
            val startTime = clock()
            for (step in 1..steps) {
                delay(startTime + durationMillis * step / steps - clock())
                val fraction = step.toDouble() / steps
                fingers.move(from.zip(to) { start, end -> Point(start.x + (end.x - start.x) * fraction, start.y + (end.y - start.y) * fraction) })
            }
        }
    }

    fun pressKey(name: String) {
        val code = KeyEvent.keyCodeFromString(name)
        if (code == KeyEvent.KEYCODE_UNKNOWN) throw AgentError("Unknown key $name", AgentErrorCode.INVALID_ARGUMENTS)
        val time = SystemClock.uptimeMillis()
        keys(KeyEvent(time, time, KeyEvent.ACTION_DOWN, code, 0))
        keys(KeyEvent(time, SystemClock.uptimeMillis(), KeyEvent.ACTION_UP, code, 0))
    }

    /** Types [text] as key presses, which only covers the characters of a keyboard's key map. */
    fun typeKeys(text: String) {
        val keyMap = KeyCharacterMap.load(KeyCharacterMap.VIRTUAL_KEYBOARD)
        val events = keyMap.getEvents(text.toCharArray()) ?: throw AgentError(
            "No keys type \"$text\"",
            AgentErrorCode.INVALID_ARGUMENTS,
            "Focus a text field first, which takes any text",
        )
        events.forEach { keys(KeyEvent.changeTimeRepeat(it, SystemClock.uptimeMillis(), 0)) }
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
        private val downTime = clock()

        fun down() {
            touches.send(downTime, MotionEvent.ACTION_DOWN, points.take(1), waitForDelivery = true)
            if (points.size > 1) touches.send(downTime, pointer(MotionEvent.ACTION_POINTER_DOWN), points, waitForDelivery = true)
        }

        fun move(to: List<Point>) {
            points = to
            touches.send(downTime, MotionEvent.ACTION_MOVE, points, waitForDelivery = false)
        }

        fun up() {
            if (points.size > 1) touches.send(downTime, pointer(MotionEvent.ACTION_POINTER_UP), points, waitForDelivery = true)
            touches.send(downTime, MotionEvent.ACTION_UP, points.take(1), waitForDelivery = true)
        }

        fun cancel() = touches.send(downTime, MotionEvent.ACTION_CANCEL, points, waitForDelivery = true)

        private fun pointer(action: Int) = action or (1 shl MotionEvent.ACTION_POINTER_INDEX_SHIFT)
    }

    private companion object {
        const val TAP_HOLD_MILLIS = 50L
        const val BETWEEN_TAPS_MILLIS = 80L
        const val MOVE_INTERVAL_MILLIS = 10L
        const val MIN_MOVES = 2
    }
}

/** Where a gesture's touches go: the input system in the helper, a recorder in tests. */
internal fun interface TouchInput {
    /**
     * Sends a touch [action] of the gesture that went down at [downTime], with a finger at each of [points]. With
     * [waitForDelivery] it returns once the window that gets it has handled it.
     */
    fun send(downTime: Long, action: Int, points: List<Point>, waitForDelivery: Boolean)
}

/** Touches through [UiAutomation], which the input system sends to whichever window is under them. */
private class AutomationTouches(private val automation: UiAutomation) : TouchInput {

    override fun send(downTime: Long, action: Int, points: List<Point>, waitForDelivery: Boolean) {
        val properties = Array(points.size) { index ->
            MotionEvent.PointerProperties().apply {
                id = index
                toolType = MotionEvent.TOOL_TYPE_FINGER
            }
        }
        val coordinates = Array(points.size) { index ->
            MotionEvent.PointerCoords().apply {
                x = points[index].x.toFloat()
                y = points[index].y.toFloat()
                pressure = 1f
                size = 1f
            }
        }
        val event = MotionEvent.obtain(
            downTime, SystemClock.uptimeMillis(), action, points.size, properties, coordinates,
            0, 0, 1f, 1f, 0, 0, InputDevice.SOURCE_TOUCHSCREEN, 0,
        )
        try {
            automation.injectOrFail(event, waitForDelivery)
        } finally {
            event.recycle()
        }
    }
}

private fun UiAutomation.injectOrFail(event: InputEvent, waitForDelivery: Boolean) {
    if (!injectInputEvent(event, waitForDelivery)) {
        throw AgentError("Android refused the input event", AgentErrorCode.FAILED)
    }
}

