package com.lyft.hammer.agent.ui

import android.os.SystemClock
import android.view.InputDevice
import android.view.KeyCharacterMap
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.View
import com.lyft.hammer.agent.AgentError
import com.lyft.hammer.agent.AgentErrorCode
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext
import kotlin.math.max

/**
 * Sends touches and key presses to the app's windows on the main thread, the way Compose UI tests do.
 * Injecting through the input system needs `INJECT_EVENTS`, which apps can't hold, so events start
 * at the window's root view rather than at the screen. Each one has been handled when it returns.
 */
internal class EventInjector(
    private val reader: ScreenReader,
    private val activities: ForegroundActivities,
    private val main: CoroutineDispatcher,
) {

    suspend fun tap(point: Point, density: Double, count: Int) {
        repeat(count) { index ->
            if (index > 0) delay(BETWEEN_TAPS_MILLIS)
            val gesture = begin(point, density)
            delay(TAP_HOLD_MILLIS)
            gesture.end(point)
        }
    }

    suspend fun longPress(point: Point, density: Double, durationSeconds: Double) {
        val gesture = begin(point, density)
        delay(durationSeconds.millis)
        gesture.end(point)
    }

    /** Puts a finger down at [from], moves it to [to] over [durationSeconds] and lifts it, for swipes and drags. */
    suspend fun drag(from: Point, to: Point, density: Double, durationSeconds: Double) {
        val durationMillis = durationSeconds.millis
        val steps = max(MIN_MOVES, (durationMillis / MOVE_INTERVAL_MILLIS).toInt())
        val gesture = begin(from, density)
        for (step in 1..steps) {
            delay(durationMillis / steps)
            val fraction = step.toDouble() / steps
            gesture.move(Point(from.x + (to.x - from.x) * fraction, from.y + (to.y - from.y) * fraction))
        }
        gesture.end(to)
    }

    /** Puts two fingers down at [from], moves them to [to] over [durationSeconds] and lifts them, for pinches. */
    suspend fun pinch(from: List<Point>, to: List<Point>, density: Double, durationSeconds: Double) {
        val durationMillis = durationSeconds.millis
        val steps = max(MIN_MOVES, (durationMillis / MOVE_INTERVAL_MILLIS).toInt())
        val gesture = gestureAt(from[0], density)
        withContext(main) {
            gesture.dispatchFingers(MotionEvent.ACTION_DOWN, from.take(1))
            gesture.dispatchFingers(secondFinger(MotionEvent.ACTION_POINTER_DOWN), from)
        }
        for (step in 1..steps) {
            delay(durationMillis / steps)
            val fraction = step.toDouble() / steps
            val fingers = from.zip(to) { start, end ->
                Point(start.x + (end.x - start.x) * fraction, start.y + (end.y - start.y) * fraction)
            }
            withContext(main) { gesture.dispatchFingers(MotionEvent.ACTION_MOVE, fingers) }
        }
        withContext(main) {
            gesture.dispatchFingers(secondFinger(MotionEvent.ACTION_POINTER_UP), to)
            gesture.dispatchFingers(MotionEvent.ACTION_UP, to.take(1))
        }
    }

    private fun secondFinger(action: Int) = action or (1 shl MotionEvent.ACTION_POINTER_INDEX_SHIFT)

    /** Types [text] as hardware key presses into the focused window, holding shift where a character needs it. */
    suspend fun type(text: String) {
        val keyMap = KeyCharacterMap.load(KeyCharacterMap.VIRTUAL_KEYBOARD)
        val events = text.flatMap { character ->
            keyMap.getEvents(charArrayOf(character))?.toList() ?: throw AgentError(
                "No key types the character \"$character\"",
                AgentErrorCode.INVALID_ARGUMENTS,
                "type_text types the characters of a US keyboard",
            )
        }
        dispatchKeys(events)
    }

    suspend fun press(key: Key) {
        when (key) {
            is Key.Character -> type(key.character.toString())
            is Key.Code -> dispatchKeys(KEY_ACTIONS.map { action -> KeyEvent(action, key.keyCode) })
            Key.Back -> back()
        }
    }

    /**
     * Goes back in the frontmost window. A back key sent to a window's views does nothing once the app
     * handles back with `OnBackInvokedCallback`, which only the input system calls, so an activity
     * gets `onBackPressed`, which runs its override or its `OnBackPressedDispatcher`, and other
     * windows, such as Compose dialogs, get their `OnBackPressedDispatcher` when they have one.
     */
    @Suppress("DEPRECATION") // onBackPressed is the one call that reaches both an override and the dispatcher
    private suspend fun back() = withContext(main) {
        val window = focusedWindow()
        val activity = activities.activity(window)
        when {
            activity != null -> activity.onBackPressed()
            OptionalLibraries.hasActivity && BackDispatchers.pressBack(window) -> Unit
            else -> KEY_ACTIONS.forEach { action -> window.dispatchKeyEvent(KeyEvent(action, KeyEvent.KEYCODE_BACK)) }
        }
    }

    private suspend fun dispatchKeys(events: List<KeyEvent>) = withContext(main) {
        val window = focusedWindow()
        events.forEach { window.dispatchKeyEvent(KeyEvent.changeTimeRepeat(it, SystemClock.uptimeMillis(), 0)) }
    }

    private fun focusedWindow(): View {
        val roots = reader.windowRoots()
        return roots.lastOrNull { it.hasWindowFocus() } ?: roots.lastOrNull() ?: throw notReady()
    }

    /** Puts a finger down in the frontmost window at [start]. */
    private suspend fun begin(start: Point, density: Double): Gesture =
        gestureAt(start, density).also { withContext(main) { it.dispatch(MotionEvent.ACTION_DOWN, start) } }

    /** A touch in the frontmost window at [start], before any finger is down. */
    private suspend fun gestureAt(start: Point, density: Double): Gesture = withContext(main) {
        val x = (start.x * density).toInt()
        val y = (start.y * density).toInt()
        val roots = reader.windowRoots()
        val window = roots.lastOrNull { ScreenReader.screenBounds(it).contains(x, y) } ?: roots.lastOrNull() ?: throw notReady()
        Gesture(window, density)
    }

    /** One finger's touch, sent to the window it went down in until it lifts. */
    private inner class Gesture(private val window: View, private val density: Double) {

        private val origin = IntArray(2).also(window::getLocationOnScreen)
        private val downTime = SystemClock.uptimeMillis()

        suspend fun move(point: Point) = withContext(main) { dispatch(MotionEvent.ACTION_MOVE, point) }

        suspend fun end(point: Point) = withContext(main) { dispatch(MotionEvent.ACTION_UP, point) }

        fun dispatch(action: Int, point: Point) {
            val event = MotionEvent.obtain(
                downTime,
                SystemClock.uptimeMillis(),
                action,
                (point.x * density - origin[0]).toFloat(),
                (point.y * density - origin[1]).toFloat(),
                0,
            )
            event.source = InputDevice.SOURCE_TOUCHSCREEN
            send(event)
        }

        /** Sends an event with a finger at each of [points], the first one's pointer id 0, the next one's 1. */
        fun dispatchFingers(action: Int, points: List<Point>) {
            val properties = Array(points.size) { index ->
                MotionEvent.PointerProperties().apply {
                    id = index
                    toolType = MotionEvent.TOOL_TYPE_FINGER
                }
            }
            val coordinates = Array(points.size) { index ->
                MotionEvent.PointerCoords().apply {
                    x = (points[index].x * density - origin[0]).toFloat()
                    y = (points[index].y * density - origin[1]).toFloat()
                    pressure = 1f
                    size = 1f
                }
            }
            val event = MotionEvent.obtain(
                downTime,
                SystemClock.uptimeMillis(),
                action,
                points.size,
                properties,
                coordinates,
                0,
                0,
                1f,
                1f,
                0,
                0,
                InputDevice.SOURCE_TOUCHSCREEN,
                0,
            )
            send(event)
        }

        private fun send(event: MotionEvent) {
            try {
                window.dispatchTouchEvent(event)
            } finally {
                event.recycle()
            }
        }
    }

    private val Double.millis: Long
        get() = (this * MILLIS_PER_SECOND).toLong()

    private fun notReady() = AgentError("The app has no window in the foreground", AgentErrorCode.NOT_READY)

    private companion object {
        const val TAP_HOLD_MILLIS = 50L
        const val BETWEEN_TAPS_MILLIS = 80L
        const val MOVE_INTERVAL_MILLIS = 10L
        const val MIN_MOVES = 2
        const val MILLIS_PER_SECOND = 1000
        val KEY_ACTIONS = listOf(KeyEvent.ACTION_DOWN, KeyEvent.ACTION_UP)
    }
}
