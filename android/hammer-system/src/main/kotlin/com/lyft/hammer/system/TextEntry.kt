package com.lyft.hammer.system

import android.app.UiAutomation
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
        val field = automation.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
            ?: throw AgentError(
                "No text field has focus",
                AgentErrorCode.NOT_READY,
                "Tap the field first, or pass it as the target",
            )
        // The node can be from the cache, with the text and cursor of an earlier read
        field.refresh()
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

        val cursor = Bundle().apply {
            putInt(AccessibilityNodeInfo.ACTION_ARGUMENT_SELECTION_START_INT, insertion.cursor)
            putInt(AccessibilityNodeInfo.ACTION_ARGUMENT_SELECTION_END_INT, insertion.cursor)
        }
        field.performAction(AccessibilityNodeInfo.ACTION_SET_SELECTION, cursor)
        return true
    }

    /** A field's text after typing, and where its cursor goes. */
    data class Insertion(val text: String, val cursor: Int)

    companion object {
        private const val SET_TEXT = "set_text"
        private const val KEYS = "keys"

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
