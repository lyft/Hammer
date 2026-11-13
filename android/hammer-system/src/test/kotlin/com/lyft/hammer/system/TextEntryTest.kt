package com.lyft.hammer.system

import org.assertj.core.api.Assertions.assertThat
import org.junit.Test

class TextEntryTest {

    @Test
    fun textGoesAtTheCursor() {
        assertThat(TextEntry.insert("X", into = "hello", 2, 2)).isEqualTo(TextEntry.Insertion("heXllo", 3))
    }

    @Test
    fun textReplacesTheSelection() {
        assertThat(TextEntry.insert("X", into = "hello", 1, 4)).isEqualTo(TextEntry.Insertion("hXo", 2))
        assertThat(TextEntry.insert("X", into = "hello", 4, 1)).isEqualTo(TextEntry.Insertion("hXo", 2))
    }

    @Test
    fun fieldWithoutASelectionGetsTheTextAtItsEnd() {
        assertThat(TextEntry.insert("X", into = "hello", -1, -1)).isEqualTo(TextEntry.Insertion("helloX", 6))
    }

    @Test
    fun selectionPastTheTextIsIgnored() {
        assertThat(TextEntry.insert("X", into = "hi", 0, 5)).isEqualTo(TextEntry.Insertion("hiX", 3))
    }

    @Test
    fun emptyFieldGetsTheText() {
        assertThat(TextEntry.insert("abc", into = "", 0, 0)).isEqualTo(TextEntry.Insertion("abc", 3))
    }
}
