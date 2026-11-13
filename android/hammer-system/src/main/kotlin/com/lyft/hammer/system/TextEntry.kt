package com.lyft.hammer.system

import android.app.UiAutomation
import android.os.Build
import android.os.Bundle
import android.view.accessibility.AccessibilityNodeInfo
import com.lyft.hammer.agent.AgentError
import com.lyft.hammer.agent.AgentErrorCode

/**
 * Types into the focused field by setting its text through accessibility, which takes any characters, or with
 * key presses when the field doesn't take that, such as a game's own input.
 */
internal class TextEntry(private val automation: UiAutomation, private val input: InputInjector) {

    /** @return how the text was typed: `set_text` or `keys`. */
    fun type(text: String): String {
        val field = automation.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
        if (field != null && field.isEditable && setText(field, text)) return SET_TEXT
        if (field == null) {
            throw AgentError(
                "No text field has focus",
                AgentErrorCode.NOT_READY,
                "Tap the field first, or pass it as the target",
            )
        }
        input.typeKeys(text)
        return KEYS
    }

    // Setting the text replaces it, so the field's own text is kept and the new text goes at its end, where a
    // field's cursor is after a tap
    private fun setText(field: AccessibilityNodeInfo, text: String): Boolean {
        val showingHint = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && field.isShowingHintText
        val current = if (showingHint) "" else field.text?.toString().orEmpty()
        val arguments = Bundle().apply {
            putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, current + text)
        }
        return field.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, arguments)
    }

    private companion object {
        const val SET_TEXT = "set_text"
        const val KEYS = "keys"
    }
}
