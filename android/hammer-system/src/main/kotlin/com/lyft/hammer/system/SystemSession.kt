package com.lyft.hammer.system

import android.app.UiAutomation
import android.content.Context
import android.os.Build
import com.lyft.hammer.agent.AgentError
import com.lyft.hammer.agent.AgentErrorCode
import com.lyft.hammer.agent.CommandDescriptor
import com.lyft.hammer.agent.CommandDescriptor.Parameter
import com.lyft.hammer.agent.CommandDescriptor.ParameterType
import com.lyft.hammer.agent.JsonValue
import com.lyft.hammer.agent.core.AgentImage
import com.lyft.hammer.agent.core.WireCommand
import com.lyft.hammer.agent.core.emptyJsonObject
import com.lyft.hammer.agent.core.json
import com.lyft.hammer.agent.core.jsonObject
import java.io.File
import java.security.MessageDigest
import java.util.concurrent.TimeoutException
import java.util.concurrent.atomic.AtomicLong

/**
 * The helper's commands. They take and report pixels, and the hammer tool converts to dp, finds elements and
 * picks points, as it does for uiautomator's output, so both read the same.
 */
internal class SystemSession(
    private val automation: UiAutomation,
    private val context: Context,
    private val stop: () -> Unit,
    private val clock: () -> Long = System::currentTimeMillis,
) {
    private val lastUse = AtomicLong(clock())
    private val reader = WindowReader(automation)
    private val input = InputInjector(automation)

    fun idleMillis(): Long = clock() - lastUse.get()

    val commands: List<WireCommand> = listOf(
        command(VERSION) {
            jsonObject("version" to apkDigest.json, "sdk" to Build.VERSION.SDK_INT.json)
        },
        command(STOP) {
            // After the response, so the tool reads it before the socket closes
            Thread { Thread.sleep(STOP_DELAY_MILLIS); stop() }.start()
            emptyJsonObject
        },
        command(DESCRIBE) { arguments ->
            WindowJson.encode(reader.windows(), arguments.string("package"))
        },
        command(TAP) { arguments ->
            input.tap(arguments.point(), count = arguments.number("count")?.toInt() ?: 1)
            emptyJsonObject
        },
        command(LONG_PRESS) { arguments ->
            input.longPress(arguments.point(), arguments.millis("duration") ?: DEFAULT_LONG_PRESS_MILLIS)
            emptyJsonObject
        },
        command(SWIPE) { arguments ->
            val from = Point(arguments.requiredNumber("x"), arguments.requiredNumber("y"))
            val to = Point(arguments.requiredNumber("to_x"), arguments.requiredNumber("to_y"))
            input.drag(listOf(from), listOf(to), arguments.millis("duration") ?: DEFAULT_SWIPE_MILLIS)
            emptyJsonObject
        },
        command(PINCH) { arguments ->
            val from = arguments.points("from")
            val to = arguments.points("to")
            if (from.size != 2 || to.size != 2) throw invalid("from and to each need two points")
            input.drag(from, to, arguments.millis("duration") ?: DEFAULT_PINCH_MILLIS)
            emptyJsonObject
        },
        command(PRESS_KEY) { arguments ->
            input.pressKey(arguments.requiredString("key"))
            emptyJsonObject
        },
        command(TYPE_TEXT) { arguments ->
            jsonObject("method" to TextEntry(automation, input).type(arguments.requiredString("text")).json)
        },
        command(SCREENSHOT) { arguments ->
            AgentImage.png(Screenshots(automation).png(arguments.area(), arguments.size()))
        },
        command(WAIT_FOR_IDLE) { arguments ->
            val timeout = arguments.millis("timeout") ?: DEFAULT_IDLE_TIMEOUT_MILLIS
            try {
                automation.waitForIdle(arguments.millis("quiet") ?: DEFAULT_QUIET_MILLIS, timeout)
            } catch (error: TimeoutException) {
                throw AgentError("The screen was still changing after ${timeout / MILLIS_PER_SECOND} seconds", AgentErrorCode.TIMED_OUT)
            }
            emptyJsonObject
        },
    )

    /** The SHA-256 of the helper's APK, which the tool compares with the APK it embeds to know it is current. */
    private val apkDigest: String by lazy {
        val digest = MessageDigest.getInstance("SHA-256")
        File(context.packageCodePath).inputStream().use { input ->
            val buffer = ByteArray(DIGEST_BUFFER_BYTES)
            while (true) {
                val read = input.read(buffer)
                if (read < 0) break
                digest.update(buffer, 0, read)
            }
        }
        digest.digest().joinToString("") { "%02x".format(it) }
    }

    private fun command(descriptor: CommandDescriptor, run: suspend (JsonValue.Object) -> JsonValue): WireCommand =
        object : WireCommand {
            override val descriptor = descriptor

            override suspend fun run(arguments: JsonValue.Object): JsonValue {
                lastUse.set(clock())
                return try {
                    run(arguments)
                } finally {
                    lastUse.set(clock())
                }
            }
        }

    private fun JsonValue.Object.number(name: String): Double? = this[name]?.numberValue
    private fun JsonValue.Object.string(name: String): String? = this[name]?.stringValue
    private fun JsonValue.Object.requiredNumber(name: String): Double = number(name) ?: throw invalid("Missing $name")
    private fun JsonValue.Object.requiredString(name: String): String = string(name) ?: throw invalid("Missing $name")
    private fun JsonValue.Object.millis(name: String): Long? = number(name)?.let { (it * MILLIS_PER_SECOND).toLong() }
    private fun JsonValue.Object.point() = Point(requiredNumber("x"), requiredNumber("y"))

    private fun JsonValue.Object.points(name: String): List<Point> = this[name]?.arrayValue.orEmpty().map { point ->
        val coordinates = point.arrayValue?.mapNotNull { it.numberValue }
        if (coordinates?.size != 2) throw invalid("Each point of $name is [x, y]")
        Point(coordinates[0], coordinates[1])
    }

    private fun JsonValue.Object.area(): Area? {
        val values = listOf("area_x", "area_y", "area_width", "area_height").map { number(it) }
        if (values.all { it == null }) return null
        if (values.any { it == null }) throw invalid("Pass all of area_x, area_y, area_width and area_height, or none")
        return Area(values[0]!!.toInt(), values[1]!!.toInt(), values[2]!!.toInt(), values[3]!!.toInt())
    }

    private fun JsonValue.Object.size(): Pair<Int, Int>? {
        val width = number("width")?.toInt()
        val height = number("height")?.toInt()
        if ((width == null) != (height == null)) throw invalid("Pass both width and height, or neither")
        return if (width != null && height != null) width to height else null
    }

    private fun invalid(message: String) = AgentError(message, AgentErrorCode.INVALID_ARGUMENTS)

    private companion object {
        const val DEFAULT_LONG_PRESS_MILLIS = 2_000L
        const val DEFAULT_SWIPE_MILLIS = 200L
        const val DEFAULT_PINCH_MILLIS = 500L
        const val DEFAULT_IDLE_TIMEOUT_MILLIS = 10_000L
        const val DEFAULT_QUIET_MILLIS = 300L
        const val MILLIS_PER_SECOND = 1000
        const val STOP_DELAY_MILLIS = 100L
        const val DIGEST_BUFFER_BYTES = 64 * 1024

        private fun number(name: String, summary: String, required: Boolean = false) =
            Parameter(name, ParameterType.NumberValue, summary, isRequired = required)

        private val X = number("x", "The x coordinate in pixels", required = true)
        private val Y = number("y", "The y coordinate in pixels", required = true)
        private val DURATION = number("duration", "How long the gesture takes, in seconds")

        val VERSION = CommandDescriptor("version", "The SHA-256 of the helper's APK and the device's SDK level")
        val STOP = CommandDescriptor("stop", "Stops the helper, freeing UiAutomation for other tools")
        val DESCRIBE = CommandDescriptor(
            "describe",
            "Every window on screen back to front, with its accessibility nodes, in pixels",
            listOf(Parameter("package", ParameterType.StringValue, "Only the windows of this app")),
        )
        val TAP = CommandDescriptor("tap", "Taps a point", listOf(X, Y, number("count", "How many taps")))
        val LONG_PRESS = CommandDescriptor("long_press", "Presses and holds a point", listOf(X, Y, DURATION))
        val SWIPE = CommandDescriptor(
            "swipe",
            "Moves one finger from a point to another",
            listOf(X, Y, number("to_x", "Where it ends", required = true), number("to_y", "Where it ends", required = true), DURATION),
        )
        val PINCH = CommandDescriptor(
            "pinch",
            "Moves two fingers from two points to two others",
            listOf(
                Parameter("from", ParameterType.Json, "The two starting points, as [[x, y], [x, y]]", isRequired = true),
                Parameter("to", ParameterType.Json, "The two ending points", isRequired = true),
                DURATION,
            ),
        )
        val PRESS_KEY = CommandDescriptor(
            "press_key",
            "Presses a key",
            listOf(Parameter("key", ParameterType.StringValue, "The key code name, such as KEYCODE_BACK", isRequired = true)),
        )
        val TYPE_TEXT = CommandDescriptor(
            "type_text",
            "Types text into the focused field",
            listOf(Parameter("text", ParameterType.StringValue, "The text", isRequired = true)),
        )
        val SCREENSHOT = CommandDescriptor(
            "screenshot",
            "A PNG of the screen, or of an area, scaled to a size",
            listOf(
                number("area_x", "The area's left edge"),
                number("area_y", "The area's top edge"),
                number("area_width", "The area's width"),
                number("area_height", "The area's height"),
                number("width", "The image's width"),
                number("height", "The image's height"),
            ),
        )
        val WAIT_FOR_IDLE = CommandDescriptor(
            "wait_for_idle",
            "Waits until no accessibility events arrive for a while",
            listOf(number("quiet", "How long the screen must stay quiet, in seconds"), number("timeout", "How long to wait, in seconds")),
        )
    }
}

internal data class Point(val x: Double, val y: Double)

internal data class Area(val x: Int, val y: Int, val width: Int, val height: Int)
