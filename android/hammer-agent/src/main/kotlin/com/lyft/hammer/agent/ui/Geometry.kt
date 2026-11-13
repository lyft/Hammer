package com.lyft.hammer.agent.ui

import com.lyft.hammer.agent.JsonValue
import com.lyft.hammer.agent.core.json
import com.lyft.hammer.agent.core.jsonObject
import kotlin.math.abs
import kotlin.math.roundToLong

/** A point in screen dp, Android's counterpart of Hammer's window points. */
internal data class Point(val x: Double, val y: Double) {
    fun isNear(other: Point, tolerance: Double = 1.0) = abs(x - other.x) <= tolerance && abs(y - other.y) <= tolerance
}

/** A rectangle in screen dp. */
internal data class Frame(val x: Double, val y: Double, val width: Double, val height: Double) {

    val isEmpty: Boolean
        get() = width <= 0 || height <= 0

    val center: Point
        get() = Point(x + width / 2, y + height / 2)

    operator fun contains(point: Point) = point.x >= x && point.x < x + width && point.y >= y && point.y < y + height

    fun toJson(decimals: Int): JsonValue.Object = jsonObject(
        "x" to round(x, decimals).json,
        "y" to round(y, decimals).json,
        "width" to round(width, decimals).json,
        "height" to round(height, decimals).json,
    )

    companion object {
        /** Whole numbers are written without a fraction, as Hammer's JSON encoder does. */
        fun round(value: Double, decimals: Int): Number {
            var factor = 1.0
            repeat(decimals) { factor *= 10 }
            val rounded = (value * factor).roundToLong() / factor
            return if (rounded == Math.rint(rounded)) rounded.toLong() else rounded
        }
    }
}
