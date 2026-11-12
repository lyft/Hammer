package com.lyft.hammer.agent.ui

import android.view.KeyEvent
import com.lyft.hammer.agent.AgentError
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.catchThrowableOfType
import org.junit.Test

class KeysTest {

    @Test
    fun parse_hammerKeyName_isItsKeyCode() {
        assertThat(Keys.parse("returnOrEnter")).isEqualTo(Key.Code(KeyEvent.KEYCODE_ENTER))
        assertThat(Keys.parse("deleteOrBackspace")).isEqualTo(Key.Code(KeyEvent.KEYCODE_DEL))
        assertThat(Keys.parse("arrowUp")).isEqualTo(Key.Code(KeyEvent.KEYCODE_DPAD_UP))
    }

    @Test
    fun parse_numberedNames_countFromTheFirstKey() {
        assertThat(Keys.parse("letterZ")).isEqualTo(Key.Code(KeyEvent.KEYCODE_Z))
        assertThat(Keys.parse("number0")).isEqualTo(Key.Code(KeyEvent.KEYCODE_0))
        assertThat(Keys.parse("number9")).isEqualTo(Key.Code(KeyEvent.KEYCODE_9))
        assertThat(Keys.parse("functionF12")).isEqualTo(Key.Code(KeyEvent.KEYCODE_F12))
    }

    @Test
    fun parse_deviceBack_isBack() {
        assertThat(Keys.parse("deviceBack")).isEqualTo(Key.Back)
    }

    @Test
    fun parse_singleCharacter_isTheCharacter() {
        assertThat(Keys.parse("?")).isEqualTo(Key.Character('?'))
    }

    @Test
    fun parse_misspelledName_suggestsTheKey() {
        val error = catchThrowableOfType({ Keys.parse("retunOrEnter") }, AgentError::class.java)

        assertThat(error.code).isEqualTo("invalid_arguments")
        assertThat(error.message).isEqualTo("Unknown key \"retunOrEnter\", did you mean returnOrEnter?")
    }
}
