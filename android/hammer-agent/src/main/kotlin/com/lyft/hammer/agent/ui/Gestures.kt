package com.lyft.hammer.agent.ui

import com.lyft.hammer.agent.core.BuiltinCommands

/** Where swipes start and end, with the geometry of Hammer's `EventGenerator`. */
internal object Gestures {

    /** The line a finger moves along: [distance] long in [direction], centered on [center]. */
    fun swipe(center: Point, direction: String, distance: Double): Pair<Point, Point> {
        val (dx, dy) = vector(direction)
        return Point(center.x - dx * distance / 2, center.y - dy * distance / 2) to
            Point(center.x + dx * distance / 2, center.y + dy * distance / 2)
    }

    /** The line from the edge of [screen] opposite [direction], starting just inside it so the touch lands. */
    fun edgeSwipe(screen: Frame, direction: String, distance: Double): Pair<Point, Point> {
        val inner = Frame(
            screen.x + EDGE_INSET,
            screen.y + EDGE_INSET,
            screen.width - 2 * EDGE_INSET,
            screen.height - 2 * EDGE_INSET,
        )
        val (dx, dy) = vector(direction)
        val start = Point(inner.center.x - dx * inner.width / 2, inner.center.y - dy * inner.height / 2)
        return start to Point(start.x + dx * distance, start.y + dy * distance)
    }

    private fun vector(direction: String): Pair<Double, Double> = when (direction) {
        "up" -> 0.0 to -1.0
        "down" -> 0.0 to 1.0
        "left" -> -1.0 to 0.0
        "right" -> 1.0 to 0.0
        else -> throw Target.invalid(
            "Unknown direction \"$direction\"",
            hint = "Use one of ${BuiltinCommands.SWIPE_DIRECTIONS.joinToString(", ")}",
        )
    }

    private const val EDGE_INSET = 1.0
}
