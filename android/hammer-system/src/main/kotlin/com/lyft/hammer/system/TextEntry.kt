package com.lyft.hammer.system

import android.app.UiAutomation
import android.os.Build
import android.os.Bundle
import android.view.accessibility.AccessibilityNodeInfo
import com.lyft.hammer.agent.AgentError
import com.lyft.hammer.agent.AgentErrorCode

/**
 * Types into the focused field with key presses, as a hardware keyboard does, so the field's own input handling
 * puts the text at its cursor, even in a field that formats what it shows, such as a phone number. Text with a
 * character no key types is set through accessibility instead, at the end of the field's text.
 */
internal class TextEntry(private val automation: UiAutomation, private val input: InputInjector) {

    /** @return how the text was typed: `keys` or `set_text`. */
    fun type(text: String): String {
        val field = focusedField() ?: throw AgentError(
            "No text field has focus",
            AgentErrorCode.NOT_READY,
            "Tap the field first, or pass it as the target",
        )
        val current = ownText(field)
        // A password field reports its text masked, which setting the text would write back
        val masked = field.isPassword && current.isNotEmpty()
        return when (method(input.hasKeys(text), settable = field.isEditable && !masked)) {
            KEYS -> {
                input.typeKeys(text)
                KEYS
            }
            SET_TEXT -> {
                if (!append(field, current, text)) throw noKeys(text, masked)
                SET_TEXT
            }
            else -> throw noKeys(text, masked)
        }
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

    // A field that formats what it shows reports the formatted text with a cursor in its unformatted text, and
    // sets the unformatted text, so no cursor can be computed or sent: the text goes at the end, where setting
    // the text leaves the cursor
    private fun append(field: AccessibilityNodeInfo, current: String, text: String): Boolean {
        val arguments = Bundle().apply {
            putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, current + text)
        }
        return field.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, arguments)
    }

    private fun noKeys(text: String, masked: Boolean): AgentError {
        if (masked) {
            return AgentError(
                "No keys type \"$text\" into the password field, which already has text that can't be read",
                AgentErrorCode.INVALID_ARGUMENTS,
                "Clear the field first, then type the whole text",
            )
        }
        return AgentError(
            "No keys type \"$text\"",
            AgentErrorCode.INVALID_ARGUMENTS,
            "Focus a text field first, which takes any text",
        )
    }

    companion object {
        private const val SET_TEXT = "set_text"
        private const val KEYS = "keys"

        /** The cached focus while it still has the focus, or else the focused field a search finds. */
        fun <Field : Any> stillFocused(cached: Field?, isFocused: (Field) -> Boolean, search: () -> Field?): Field? =
            cached?.takeIf(isFocused) ?: search()

        /**
         * How text is typed: with keys whenever every character has one, else by setting the text of a field
         * that takes it, or `null` when neither works.
         */
        fun method(hasKeys: Boolean, settable: Boolean): String? = when {
            hasKeys -> KEYS
            settable -> SET_TEXT
            else -> null
        }
    }
}
