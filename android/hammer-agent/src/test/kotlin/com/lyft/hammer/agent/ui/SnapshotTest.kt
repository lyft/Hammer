package com.lyft.hammer.agent.ui

import org.assertj.core.api.Assertions.assertThat
import org.junit.Test

class SnapshotTest {

    @Test
    fun init_buttonOnWindow_isHittable() {
        val button = element("e2", Frame(10.0, 10.0, 100.0, 40.0), consumesTouches = true)

        Snapshot(listOf(window(button)), SCREEN)

        assertThat(button.hittable).isTrue()
    }

    @Test
    fun init_labelInsideClickableCard_isHittable() {
        val label = element("e3", Frame(20.0, 20.0, 50.0, 20.0), label = "Title")
        val card = element("e2", Frame(10.0, 10.0, 200.0, 100.0), consumesTouches = true, children = listOf(label))

        Snapshot(listOf(window(card)), SCREEN)

        assertThat(label.hittable).isTrue()
    }

    @Test
    fun init_rowAroundButton_isHittable() {
        val button = element("e3", Frame(0.0, 0.0, 400.0, 100.0), consumesTouches = true)
        val row = element("e2", Frame(0.0, 0.0, 400.0, 100.0), label = "Row", children = listOf(button))

        Snapshot(listOf(window(row)), SCREEN)

        assertThat(row.hittable).isTrue()
    }

    @Test
    fun init_buttonUnderLaterSibling_isNotHittable() {
        val button = element("e2", Frame(10.0, 10.0, 100.0, 40.0), consumesTouches = true)
        val overlay = element("e3", Frame(0.0, 0.0, 400.0, 400.0), consumesTouches = true)

        Snapshot(listOf(window(button, overlay)), SCREEN)

        assertThat(button.hittable).isFalse()
        assertThat(overlay.hittable).isTrue()
    }

    @Test
    fun init_buttonUnderDialogWindow_isNotHittable() {
        val button = element("e2", Frame(10.0, 10.0, 100.0, 40.0), consumesTouches = true)
        val dialog = element("e4", Frame(0.0, 0.0, 400.0, 800.0), consumesTouches = true)

        Snapshot(listOf(window(button), dialog), Frame(0.0, 0.0, 400.0, 800.0))

        assertThat(button.hittable).isFalse()
    }

    @Test
    fun init_buttonOutsideASmallDialog_isNotHittable() {
        val button = element("e2", Frame(10.0, 10.0, 100.0, 40.0), consumesTouches = true)
        val dialog = element("e4", Frame(50.0, 300.0, 300.0, 200.0), consumesTouches = true)

        val snapshot = Snapshot(listOf(window(button), dialog), dialog.frame)

        assertThat(button.hittable).isFalse()
        assertThat(snapshot.receiver(button.touchPoint)).isSameAs(dialog)
    }

    @Test
    fun init_buttonOutsideANotTouchModalWindow_isHittable() {
        val button = element("e2", Frame(10.0, 10.0, 100.0, 40.0), consumesTouches = true)
        val popup = element("e4", Frame(50.0, 300.0, 300.0, 200.0), consumesTouches = true)
        val activity = window(button)

        Snapshot(listOf(activity, popup), popup.frame, touches = listOf(WindowTouch(SCREEN), WindowTouch(popup.frame, modal = false)))

        assertThat(button.hittable).isTrue()
    }

    @Test
    fun init_buttonUnderANotTouchableWindow_isHittable() {
        val button = element("e2", Frame(10.0, 10.0, 100.0, 40.0), consumesTouches = true)
        val toast = element("e4", SCREEN, consumesTouches = true)

        Snapshot(listOf(window(button), toast), SCREEN, touches = listOf(WindowTouch(SCREEN), WindowTouch(SCREEN, touchable = false)))

        assertThat(button.hittable).isTrue()
    }

    @Test
    fun init_buttonUnderNonClickableOverlay_isHittable() {
        val button = element("e2", Frame(10.0, 10.0, 100.0, 40.0), consumesTouches = true)
        val overlay = element("e3", Frame(0.0, 0.0, 400.0, 400.0))

        Snapshot(listOf(window(button, overlay)), SCREEN)

        assertThat(button.hittable).isTrue()
    }

    @Test
    fun init_invisibleElement_isNotHittable() {
        val button = element("e2", Frame(10.0, 10.0, 100.0, 40.0), visible = false, consumesTouches = true)

        Snapshot(listOf(window(button)), SCREEN)

        assertThat(button.hittable).isFalse()
    }

    @Test
    fun elements_nestedTree_isInDrawingOrder() {
        val first = element("e3", Frame(0.0, 0.0, 10.0, 10.0))
        val parent = element("e2", Frame(0.0, 0.0, 100.0, 100.0), children = listOf(first))
        val second = element("e4", Frame(0.0, 0.0, 10.0, 10.0))

        val snapshot = Snapshot(listOf(window(parent, second)), SCREEN)

        assertThat(snapshot.elements.map { it.ref }).containsExactly("e1", "e2", "e3", "e4")
        assertThat(snapshot.element("e3")).isSameAs(first)
        assertThat(snapshot.element("e9")).isNull()
    }
}
