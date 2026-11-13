package com.lyft.hammer.agent.ui

import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.Test

class TouchWindowsTest {

    private val dialog = Frame(50.0, 300.0, 300.0, 200.0)

    @Test
    fun touchedWindow_insideTheFrontWindow_isTheFrontWindow() {
        assertThat(touchedWindow(listOf(WindowTouch(SCREEN), WindowTouch(dialog)), Point(100.0, 400.0))).isEqualTo(1)
    }

    @Test
    fun touchedWindow_outsideAModalWindow_isTheModalWindow() {
        assertThat(touchedWindow(listOf(WindowTouch(SCREEN), WindowTouch(dialog)), Point(10.0, 10.0))).isEqualTo(1)
    }

    @Test
    fun touchedWindow_outsideANotTouchModalWindow_isTheWindowBehind() {
        assertThat(touchedWindow(listOf(WindowTouch(SCREEN), WindowTouch(dialog, modal = false)), Point(10.0, 10.0))).isEqualTo(0)
    }

    @Test
    fun touchedWindow_notTouchableWindow_isSkipped() {
        assertThat(touchedWindow(listOf(WindowTouch(SCREEN), WindowTouch(SCREEN, touchable = false)), Point(10.0, 10.0))).isEqualTo(0)
    }

    @Test
    fun touchedWindow_noWindowTakesTheTouch_isNull() {
        assertThat(touchedWindow(listOf(WindowTouch(dialog, modal = false)), Point(10.0, 10.0))).isNull()
    }

    @Test
    fun whileFingerDown_bodyFinishes_doesNotCancel() = runTest {
        var cancels = 0

        val result = whileFingerDown(cancel = { cancels += 1 }) { "lifted" }

        assertThat(result).isEqualTo("lifted")
        assertThat(cancels).isEqualTo(0)
    }

    @Test
    fun whileFingerDown_bodyThrows_cancelsOnceAndRethrows() = runTest {
        var cancels = 0

        assertThatThrownBy {
            kotlinx.coroutines.runBlocking { whileFingerDown(cancel = { cancels += 1 }) { error("detached") } }
        }.hasMessage("detached")

        assertThat(cancels).isEqualTo(1)
    }

    @Test
    fun whileFingerDown_callerCancelled_stillCancelsTheTouch() = runTest {
        var cancels = 0
        val held = CompletableDeferred<Unit>()
        val gesture = launch { whileFingerDown(cancel = { cancels += 1 }) { held.await() } }
        runCurrent()

        gesture.cancel(CancellationException("timed out"))
        runCurrent()

        assertThat(gesture.isCancelled).isTrue()
        assertThat(cancels).isEqualTo(1)
    }
}
