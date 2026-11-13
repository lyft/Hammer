package com.lyft.hammer.agent.ui

import android.app.Dialog
import android.os.SystemClock
import android.view.InputDevice
import android.view.KeyCharacterMap
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.View
import android.view.Window
import android.view.inputmethod.EditorInfo
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
            gesture.whileDown {
                delay(TAP_HOLD_MILLIS)
                gesture.end(point)
            }
        }
    }

    suspend fun longPress(point: Point, density: Double, durationSeconds: Double) {
        val gesture = begin(point, density)
        gesture.whileDown {
            delay(durationSeconds.millis)
            gesture.end(point)
        }
    }

    /** Puts a finger down at [from], moves it to [to] over [durationSeconds] and lifts it, for swipes and drags. */
    suspend fun drag(from: Point, to: Point, density: Double, durationSeconds: Double) {
        val durationMillis = durationSeconds.millis
        val steps = max(MIN_MOVES, (durationMillis / MOVE_INTERVAL_MILLIS).toInt())
        val gesture = begin(from, density)
        gesture.whileDown {
            for (step in 1..steps) {
                delay(durationMillis / steps)
                val fraction = step.toDouble() / steps
                gesture.move(Point(from.x + (to.x - from.x) * fraction, from.y + (to.y - from.y) * fraction))
            }
            gesture.end(to)
        }
    }

    /** Puts two fingers down at [from], moves them to [to] over [durationSeconds] and lifts them, for pinches. */
    suspend fun pinch(from: List<Point>, to: List<Point>, density: Double, durationSeconds: Double) {
        val durationMillis = durationSeconds.millis
        val steps = max(MIN_MOVES, (durationMillis / MOVE_INTERVAL_MILLIS).toInt())
        val gesture = gestureAt(from[0], density)
        withContext(main) { gesture.dispatchFingers(MotionEvent.ACTION_DOWN, from.take(1)) }
        gesture.whileDown {
            withContext(main) { gesture.dispatchFingers(secondFinger(MotionEvent.ACTION_POINTER_DOWN), from) }
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
    }

    private fun secondFinger(action: Int) = action or (1 shl MotionEvent.ACTION_POINTER_INDEX_SHIFT)

    /**
     * Types [text] into the focused text field the way a keyboard app does, through the field's input
     * connection, so any character works in Views and Compose. A line break presses enter, which can
     * also submit the field.
     *
     * @throws AgentError if no text field has focus, since the text would go nowhere.
     */
    suspend fun type(text: String) = withContext(main) {
        val window = focusedWindow()
        val field = window.findFocus()?.takeIf { it.onCheckIsTextEditor() } ?: throw AgentError(
            "No text field has focus",
            AgentErrorCode.NOT_FOUND,
            "Pass the field as a ref, identifier, label or point to tap it first, or tap it, then type",
        )
        val connection = field.onCreateInputConnection(EditorInfo())
        text.split('\n').forEachIndexed { index, line ->
            if (index > 0) dispatchKeys(window, KEY_ACTIONS.map { action -> KeyEvent(action, KeyEvent.KEYCODE_ENTER) })
            if (line.isEmpty()) return@forEachIndexed
            if (connection != null) {
                connection.commitText(line, 1)
            } else {
                dispatchKeys(window, keyEvents(line))
            }
        }
        connection?.closeConnection()
    }

    private fun keyEvents(text: String): List<KeyEvent> {
        val keyMap = KeyCharacterMap.load(KeyCharacterMap.VIRTUAL_KEYBOARD)
        return text.flatMap { character ->
            keyMap.getEvents(charArrayOf(character))?.toList() ?: throw AgentError(
                "No key types the character \"$character\"",
                AgentErrorCode.INVALID_ARGUMENTS,
                "This field takes key presses only, which type the characters of a US keyboard",
            )
        }
    }

    suspend fun press(key: Key) {
        when (key) {
            is Key.Character -> withContext(main) { dispatchKeys(focusedWindow(), keyEvents(key.character.toString())) }
            is Key.Code -> withContext(main) { dispatchKeys(focusedWindow(), KEY_ACTIONS.map { action -> KeyEvent(action, key.keyCode) }) }
            Key.Back -> back()
        }
    }

    /**
     * Goes back in the frontmost window. A back key sent to a window's views does nothing once the app
     * handles back with `OnBackInvokedCallback`, which only the input system calls, so an activity
     * gets `onBackPressed`, which runs its override or its `OnBackPressedDispatcher`, a window with an
     * `OnBackPressedDispatcher`, such as a Compose dialog or a `ComponentDialog`, gets that, and a plain
     * `Dialog` gets `onBackPressed`. Callbacks registered with the platform's `OnBackInvokedDispatcher`
     * directly can only be reached through the input system: `hammer press-key --key deviceBack --system`.
     */
    @Suppress("DEPRECATION") // onBackPressed is the one call that reaches both an override and the dispatcher
    private suspend fun back() = withContext(main) {
        val window = focusedWindow()
        val activity = activities.activity(window)
        when {
            activity != null -> activity.onBackPressed()
            OptionalLibraries.hasActivity && BackDispatchers.pressBack(window) -> Unit
            else -> dialog(window)?.onBackPressed() ?: dispatchKeys(window, KEY_ACTIONS.map { KeyEvent(it, KeyEvent.KEYCODE_BACK) })
        }
    }

    /** The dialog whose window [root] is, through the window that every decor view keeps, as Curtains reads it. */
    private fun dialog(root: View): Dialog? = try {
        val window = root.javaClass.getDeclaredField("mWindow").apply { isAccessible = true }.get(root) as? Window
        window?.callback as? Dialog
    } catch (exception: ReflectiveOperationException) {
        null
    }

    private fun dispatchKeys(target: View, events: List<KeyEvent>) {
        events.forEach { target.dispatchKeyEvent(KeyEvent.changeTimeRepeat(it, SystemClock.uptimeMillis(), 0)) }
    }

    private fun focusedWindow(): View {
        val roots = reader.windowRoots()
        return roots.lastOrNull { it.hasWindowFocus() } ?: roots.lastOrNull() ?: throw notReady()
    }

    /** Puts a finger down in the frontmost window at [start]. */
    private suspend fun begin(start: Point, density: Double): Gesture =
        gestureAt(start, density).also { withContext(main) { it.dispatch(MotionEvent.ACTION_DOWN, start) } }

    /**
     * A touch at [start], before any finger is down, in the window the input system would send it to:
     * the frontmost touchable window under it, or a modal window in front, such as a dialog, which
     * takes the touches outside it.
     */
    private suspend fun gestureAt(start: Point, density: Double): Gesture = withContext(main) {
        val roots = reader.windowRoots()
        if (roots.isEmpty()) throw notReady()
        val window = touchedWindow(ScreenReader.touches(roots, density), start)?.let(roots::get) ?: roots.last()
        Gesture(window, density)
    }

    /** One finger's touch, sent to the window it went down in until it lifts. */
    private inner class Gesture(private val window: View, private val density: Double) {

        private val origin = IntArray(2).also(window::getLocationOnScreen)
        private val downTime = SystemClock.uptimeMillis()

        /** Where the fingers were last, for a cancel. */
        private var fingers: List<Point> = emptyList()

        suspend fun move(point: Point) = withContext(main) { dispatch(MotionEvent.ACTION_MOVE, point) }

        suspend fun end(point: Point) = withContext(main) { dispatch(MotionEvent.ACTION_UP, point) }

        /** Runs [body], which lifts the fingers, and cancels the touch if it fails or is cancelled first. */
        suspend fun <T> whileDown(body: suspend () -> T): T =
            whileFingerDown(cancel = { withContext(main) { dispatchFingers(MotionEvent.ACTION_CANCEL, fingers) } }, body = body)

        fun dispatch(action: Int, point: Point) {
            fingers = listOf(point)
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
            fingers = points
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
