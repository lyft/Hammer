package com.lyft.hammer.agent.ui

import com.lyft.hammer.agent.AgentError
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
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

    @Test
    fun pinch_zoomIn_spreadsTheFingersToTheDistance() {
        assertThat(Gestures.pinch(Point(200.0, 400.0), scale = 4.0, distance = 200.0)).isEqualTo(
            listOf(Point(175.0, 400.0), Point(225.0, 400.0)) to listOf(Point(100.0, 400.0), Point(300.0, 400.0)),
        )
    }

    @Test
    fun pinch_zoomOut_startsAtTheDistance() {
        assertThat(Gestures.pinch(Point(200.0, 400.0), scale = 0.25, distance = 200.0)).isEqualTo(
            listOf(Point(100.0, 400.0), Point(300.0, 400.0)) to listOf(Point(175.0, 400.0), Point(225.0, 400.0)),
        )
    }

    @Test
    fun pinch_scaleOfOne_isInvalid() {
        assertThatThrownBy { Gestures.pinch(Point(0.0, 0.0), scale = 1.0, distance = 200.0) }
            .isInstanceOf(AgentError::class.java)
            .hasMessage("Invalid scale 1.0, expected above 0 and other than 1")
    }

    @Test
    fun pinch_negativeDistance_isInvalid() {
        assertThatThrownBy { Gestures.pinch(Point(0.0, 0.0), scale = 2.0, distance = -1.0) }
            .isInstanceOf(AgentError::class.java)
            .hasMessage("Invalid distance -1.0, expected above 0")
    }
}
