package com.lyft.hammer.system

import org.assertj.core.api.Assertions.assertThat
import org.junit.Test

class TextEntryTest {

    @Test
    fun cachedFocusThatLostTheFocusIsReplacedByTheFocusedField() {
        val field = TextEntry.stillFocused(cached = "email", isFocused = { false }, search = { "phone" })

        assertThat(field).isEqualTo("phone")
    }

    @Test
    fun cachedFocusThatStillHasTheFocusIsUsedWithoutASearch() {
        var searched = false

        val field = TextEntry.stillFocused(cached = "phone", isFocused = { true }, search = { searched = true; "other" })

        assertThat(field).isEqualTo("phone")
        assertThat(searched).isFalse()
    }

    @Test
    fun noCachedFocusSearchesForTheFocusedField() {
        assertThat(TextEntry.stillFocused<String>(cached = null, isFocused = { true }, search = { "phone" })).isEqualTo("phone")
        assertThat(TextEntry.stillFocused<String>(cached = null, isFocused = { true }, search = { null })).isNull()
    }

    @Test
    fun textWithKeysIsTypedWithKeysEvenIntoAFieldThatTakesSetText() {
        assertThat(TextEntry.method(hasKeys = true, settable = true)).isEqualTo("keys")
        assertThat(TextEntry.method(hasKeys = true, settable = false)).isEqualTo("keys")
    }

    @Test
    fun textWithoutKeysIsSetIntoAFieldThatTakesIt() {
        assertThat(TextEntry.method(hasKeys = false, settable = true)).isEqualTo("set_text")
    }

    @Test
    fun textWithoutKeysCantBeTypedIntoAFieldThatDoesntTakeSetText() {
        assertThat(TextEntry.method(hasKeys = false, settable = false)).isNull()
    }
}
