package com.lyft.hammer.agent.ui

import com.lyft.hammer.agent.core.BuiltinCommands

/** Where swipes and pinches start and end, with the geometry of Hammer's `EventGenerator`. */
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

    /**
     * Where a pinch's two fingers start and end, side by side around [center], as `PinchDistances` in
     * Hammer's `HammerAgentCore` sets them: [distance] apart where they're farthest.
     */
    fun pinch(center: Point, scale: Double, distance: Double): Pair<List<Point>, List<Point>> {
        if (!(scale > 0) || scale == 1.0) {
            throw Target.invalid(
                "Invalid scale $scale, expected above 0 and other than 1",
                hint = "Use a scale above 1, such as 2, to zoom in and below 1, such as 0.5, to zoom out",
            )
        }
        if (!(distance > 0)) {
            throw Target.invalid(
                "Invalid distance $distance, expected above 0",
                hint = "Leave distance out for 200, or pass how far apart the fingers get",
            )
        }
        val (start, end) = if (scale > 1) distance / scale to distance else distance to distance * scale
        fun fingers(apart: Double) = listOf(Point(center.x - apart / 2, center.y), Point(center.x + apart / 2, center.y))
        return fingers(start) to fingers(end)
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
