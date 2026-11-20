package com.lyft.hammer.agent.ui

/**
 * The index of the window that key presses go to, from whether each window, back to front, can take the
 * focus, or null for none. It is the frontmost one that can, rather than the one with the focus now: a window
 * just shown, such as a dialog, is on screen a moment before it takes the focus from the window behind, and
 * the input system then sends it the keys. With none that can, such as only a toast, it is the frontmost.
 *
 * @param focusable false for each window with `FLAG_NOT_FOCUSABLE`, such as a toast or most popups.
 */
internal fun keyWindow(focusable: List<Boolean>): Int? =
    focusable.indexOfLast { it }.takeIf { it >= 0 } ?: focusable.indices.lastOrNull()
