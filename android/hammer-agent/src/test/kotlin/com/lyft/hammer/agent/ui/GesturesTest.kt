package com.lyft.hammer.agent.ui

import org.assertj.core.api.Assertions.assertThat
import org.junit.Test

class GesturesTest {

    @Test
    fun swipe_up_isCenteredOnThePoint() {
        assertThat(Gestures.swipe(Point(100.0, 400.0), "up", 200.0))
            .isEqualTo(Point(100.0, 500.0) to Point(100.0, 300.0))
    }

    @Test
    fun swipe_left_movesAlongX() {
        assertThat(Gestures.swipe(Point(100.0, 400.0), "left", 50.0))
            .isEqualTo(Point(125.0, 400.0) to Point(75.0, 400.0))
    }

    @Test
    fun edgeSwipe_right_startsInsideTheLeftEdge() {
        assertThat(Gestures.edgeSwipe(SCREEN, "right", 200.0))
            .isEqualTo(Point(1.0, 400.0) to Point(201.0, 400.0))
    }

    @Test
    fun edgeSwipe_up_startsInsideTheBottomEdge() {
        assertThat(Gestures.edgeSwipe(SCREEN, "up", 200.0))
            .isEqualTo(Point(200.0, 799.0) to Point(200.0, 599.0))
    }
}
