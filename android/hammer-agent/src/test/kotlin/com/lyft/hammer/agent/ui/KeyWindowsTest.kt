package com.lyft.hammer.agent.ui

import org.assertj.core.api.Assertions.assertThat
import org.junit.Test

class KeyWindowsTest {

    @Test
    fun keyWindow_dialogInFront_isTheDialogEvenBeforeItHasTheFocus() {
        assertThat(keyWindow(listOf(true, true))).isEqualTo(1)
    }

    @Test
    fun keyWindow_notFocusableWindowInFront_isTheWindowBehind() {
        assertThat(keyWindow(listOf(true, false))).isEqualTo(0)
    }

    @Test
    fun keyWindow_noFocusableWindow_isTheFrontWindow() {
        assertThat(keyWindow(listOf(false, false))).isEqualTo(1)
    }

    @Test
    fun keyWindow_noWindow_isNull() {
        assertThat(keyWindow(emptyList())).isNull()
    }
}
