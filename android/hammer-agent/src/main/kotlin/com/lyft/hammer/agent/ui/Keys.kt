package com.lyft.hammer.agent.ui

import android.view.KeyEvent
import com.lyft.hammer.agent.core.closestMatch

/** A key `press_key` presses. */
internal sealed interface Key {
    data class Code(val keyCode: Int) : Key
    data class Character(val character: Char) : Key

    /** The back button, which goes to the frontmost window's back handling rather than its views. */
    data object Back : Key
}

/** Hammer's `KeyboardKey` names, plus `deviceBack`, mapped to Android key codes. */
internal object Keys {

    const val DEVICE_BACK = "deviceBack"

    private val NAMED: Map<String, Int> = buildMap {
        ('A'..'Z').forEachIndexed { index, letter -> put("letter$letter", KeyEvent.KEYCODE_A + index) }
        for (digit in 0..9) put("number$digit", KeyEvent.KEYCODE_0 + digit)
        for (number in 1..12) put("functionF$number", KeyEvent.KEYCODE_F1 + number - 1)
        put("returnOrEnter", KeyEvent.KEYCODE_ENTER)
        put("escape", KeyEvent.KEYCODE_ESCAPE)
        put("deleteOrBackspace", KeyEvent.KEYCODE_DEL)
        put("deleteForward", KeyEvent.KEYCODE_FORWARD_DEL)
        put("tab", KeyEvent.KEYCODE_TAB)
        put("spacebar", KeyEvent.KEYCODE_SPACE)
        put("hyphen", KeyEvent.KEYCODE_MINUS)
        put("equalSign", KeyEvent.KEYCODE_EQUALS)
        put("openBracket", KeyEvent.KEYCODE_LEFT_BRACKET)
        put("closeBracket", KeyEvent.KEYCODE_RIGHT_BRACKET)
        put("backslash", KeyEvent.KEYCODE_BACKSLASH)
        put("semicolon", KeyEvent.KEYCODE_SEMICOLON)
        put("quote", KeyEvent.KEYCODE_APOSTROPHE)
        put("graveAccentAndTilde", KeyEvent.KEYCODE_GRAVE)
        put("comma", KeyEvent.KEYCODE_COMMA)
        put("period", KeyEvent.KEYCODE_PERIOD)
        put("slash", KeyEvent.KEYCODE_SLASH)
        put("capsLock", KeyEvent.KEYCODE_CAPS_LOCK)
        put("printScreen", KeyEvent.KEYCODE_SYSRQ)
        put("insert", KeyEvent.KEYCODE_INSERT)
        put("home", KeyEvent.KEYCODE_MOVE_HOME)
        put("end", KeyEvent.KEYCODE_MOVE_END)
        put("pageUp", KeyEvent.KEYCODE_PAGE_UP)
        put("pageDown", KeyEvent.KEYCODE_PAGE_DOWN)
        put("arrowRight", KeyEvent.KEYCODE_DPAD_RIGHT)
        put("arrowLeft", KeyEvent.KEYCODE_DPAD_LEFT)
        put("arrowDown", KeyEvent.KEYCODE_DPAD_DOWN)
        put("arrowUp", KeyEvent.KEYCODE_DPAD_UP)
        put("numLock", KeyEvent.KEYCODE_NUM_LOCK)
        put("leftControl", KeyEvent.KEYCODE_CTRL_LEFT)
        put("leftShift", KeyEvent.KEYCODE_SHIFT_LEFT)
        put("leftAlt", KeyEvent.KEYCODE_ALT_LEFT)
        put("leftGUI", KeyEvent.KEYCODE_META_LEFT)
        put("rightControl", KeyEvent.KEYCODE_CTRL_RIGHT)
        put("rightShift", KeyEvent.KEYCODE_SHIFT_RIGHT)
        put("rightAlt", KeyEvent.KEYCODE_ALT_RIGHT)
        put("rightGUI", KeyEvent.KEYCODE_META_RIGHT)
    }

    fun parse(name: String): Key {
        NAMED[name]?.let { return Key.Code(it) }
        if (name == DEVICE_BACK) return Key.Back
        name.singleOrNull()?.let { return Key.Character(it) }
        val suggestion = closestMatch(name, NAMED.keys.toList() + DEVICE_BACK)?.let { ", did you mean $it?" }.orEmpty()
        throw Target.invalid(
            "Unknown key \"$name\"$suggestion",
            hint = "Pass a single character or a key name, such as returnOrEnter, escape, deleteOrBackspace, " +
                "tab, spacebar, arrowUp, arrowDown, arrowLeft, arrowRight or deviceBack",
        )
    }
}
