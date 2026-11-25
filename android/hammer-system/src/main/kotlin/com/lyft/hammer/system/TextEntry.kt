package com.lyft.hammer.system

import android.app.UiAutomation
import android.os.Build
import android.os.Bundle
import android.view.accessibility.AccessibilityNodeInfo
import com.lyft.hammer.agent.AgentError
import com.lyft.hammer.agent.AgentErrorCode

/**
 * Types into the focused field by setting its text through accessibility, which takes any characters, or with
 * key presses when the field doesn't take that, such as a game's own input, or when its text can't be read,
 * such as a password field's.
 */
internal class TextEntry(private val automation: UiAutomation, private val input: InputInjector) {

    /** @return how the text was typed: `set_text` or `keys`. */
    fun type(text: String): String {
        val field = focusedField() ?: throw AgentError(
            "No text field has focus",
            AgentErrorCode.NOT_READY,
            "Tap the field first, or pass it as the target",
        )
        val current = ownText(field)
        // A password field reports its text masked, which setting the text would write back
        if (field.isEditable && field.isPassword && current.isNotEmpty()) {
            typeIntoPassword(text)
            return KEYS
        }
        if (field.isEditable && setText(field, current, text)) return SET_TEXT
        input.typeKeys(text)
        return KEYS
    }

    // A read fills UiAutomation's cache with the field focused then, and a tap that moves the focus doesn't
    // always update it, so the cached focus can be a field the user has left
    private fun focusedField(): AccessibilityNodeInfo? {
        clearCache()
        return stillFocused(
            cached = automation.findFocus(AccessibilityNodeInfo.FOCUS_INPUT),
            isFocused = { it.refresh() && it.isFocused },
            search = ::searchWindows,
        )
    }

    // Compose doesn't always report its focused text field to findFocus, so look for it in the windows
    private fun searchWindows(): AccessibilityNodeInfo? =
        automation.windows.asSequence().mapNotNull { it.root }.mapNotNull(::focusedIn).firstOrNull()

    private fun focusedIn(node: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        if (node.isFocused && node.isEditable) return node
        return (0 until node.childCount).asSequence().mapNotNull { node.getChild(it) }.mapNotNull(::focusedIn).firstOrNull()
    }

    // Before Android 14 UiAutomation has no clearCache, but setting its service info clears the cache too
    private fun clearCache() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            automation.clearCache()
        } else {
            automation.serviceInfo = automation.serviceInfo
        }
    }

    private fun ownText(field: AccessibilityNodeInfo): String {
        return if (field.isShowingHintText) "" else field.text?.toString().orEmpty()
    }

    private fun typeIntoPassword(text: String) {
        try {
            input.typeKeys(text)
        } catch (error: AgentError) {
            throw AgentError(
                "No keys type \"$text\" into the password field, which already has text that can't be read",
                AgentErrorCode.INVALID_ARGUMENTS,
                "Clear the field first, then type the whole text",
            )
        }
    }

    // Setting the text replaces all of it, so the new text goes into the field's own text at its cursor
    private fun setText(field: AccessibilityNodeInfo, current: String, text: String): Boolean {
        val insertion = insert(text, into = current, field.textSelectionStart, field.textSelectionEnd)
        val arguments = Bundle().apply {
            putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, insertion.text)
        }
        if (!field.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, arguments)) return false
        // Setting the text leaves the cursor at its end, and a field with a visual transformation, such as a
        // formatted phone number, can map a cursor sent before it redraws with the new text out of range
        if (!insertion.movesCursor) return true

        val cursor = Bundle().apply {
            putInt(AccessibilityNodeInfo.ACTION_ARGUMENT_SELECTION_START_INT, insertion.cursor)
            putInt(AccessibilityNodeInfo.ACTION_ARGUMENT_SELECTION_END_INT, insertion.cursor)
        }
        field.performAction(AccessibilityNodeInfo.ACTION_SET_SELECTION, cursor)
        return true
    }

    /** A field's text after typing, and where its cursor goes. */
    data class Insertion(val text: String, val cursor: Int) {
        /** Whether the cursor goes anywhere but the end, where setting the text already leaves it. */
        val movesCursor: Boolean get() = cursor != text.length
    }

    companion object {
        private const val SET_TEXT = "set_text"
        private const val KEYS = "keys"

        /** The cached focus while it still has the focus, or else the focused field a search finds. */
        fun <Field : Any> stillFocused(cached: Field?, isFocused: (Field) -> Boolean, search: () -> Field?): Field? =
            cached?.takeIf(isFocused) ?: search()

        /**
         * The text typed into a field's text, replacing its selection, or at its end when the field reports
         * no selection, such as one that wasn't focused by a tap.
         */
        fun insert(text: String, into: String, selectionStart: Int, selectionEnd: Int): Insertion {
            val start = minOf(selectionStart, selectionEnd)
            val end = maxOf(selectionStart, selectionEnd)
            if (start < 0 || end > into.length) return Insertion(into + text, into.length + text.length)
            return Insertion(into.substring(0, start) + text + into.substring(end), start + text.length)
        }
    }
}
