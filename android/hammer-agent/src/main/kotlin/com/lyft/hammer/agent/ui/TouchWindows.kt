package com.lyft.hammer.agent.ui

import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.withContext

/**
 * How a window takes touches, from its `WindowManager.LayoutParams` flags.
 *
 * @property touchable false for `FLAG_NOT_TOUCHABLE`, such as a toast, which touches pass through.
 * @property modal false for `FLAG_NOT_TOUCH_MODAL`. A modal window, such as a dialog, takes the touches
 *   outside its frame too, so the windows behind it get none.
 */
internal data class WindowTouch(val frame: Frame, val touchable: Boolean = true, val modal: Boolean = true)

/** The index of the window that a touch at [point] goes to, back to front as the input system picks it, or null for none. */
internal fun touchedWindow(windows: List<WindowTouch>, point: Point): Int? {
    for (index in windows.indices.reversed()) {
        val window = windows[index]
        if (!window.touchable) continue
        if (point in window.frame || window.modal) return index
    }
    return null
}

/**
 * Runs [body] while a finger is down and calls [cancel] if it throws or is cancelled, so the view the
 * finger went down on doesn't stay pressed. [cancel] runs even when the caller was cancelled.
 */
internal suspend fun <T> whileFingerDown(cancel: suspend () -> Unit, body: suspend () -> T): T = try {
    body()
} catch (error: Throwable) {
    withContext(NonCancellable) { cancel() }
    throw error
}
