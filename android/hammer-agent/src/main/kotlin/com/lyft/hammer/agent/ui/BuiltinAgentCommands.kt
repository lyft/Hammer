package com.lyft.hammer.agent.ui

import com.google.gson.JsonElement
import com.google.gson.JsonObject
import com.lyft.hammer.agent.CommandDescriptor
import com.lyft.hammer.agent.core.AgentImage
import com.lyft.hammer.agent.core.BuiltinCommands
import com.lyft.hammer.agent.core.WireCommand
import kotlinx.coroutines.delay
import kotlinx.coroutines.withTimeoutOrNull

/** The built-in commands the Android agent runs, with the behavior Hammer's commands reference describes. */
internal class BuiltinAgentCommands(private val screen: AgentScreen) {

    val all: List<WireCommand> = listOf(
        command(BuiltinCommands.describe) { arguments ->
            DescribeOutput.json(screen.snapshot(), all = arguments.boolean("all") ?: false)
        },
        command(BuiltinCommands.tap) { arguments ->
            val count = arguments.int("count") ?: 1
            if (count < 1) throw Target.invalid("count must be at least 1")
            val target = Target.parse(arguments)
            val snapshot = screen.snapshot()
            screen.injector.tap(TargetResolver.touchPoint(target, snapshot), snapshot.density, count)
            JsonObject()
        },
        command(BuiltinCommands.longPress) { arguments ->
            val target = Target.parse(arguments)
            val snapshot = screen.snapshot()
            val point = TargetResolver.touchPoint(target, snapshot)
            screen.injector.longPress(point, snapshot.density, arguments.double("duration") ?: DEFAULT_LONG_PRESS_SECONDS)
            JsonObject()
        },
        command(BuiltinCommands.swipe) { arguments ->
            val target = Target.parse(arguments)
            val snapshot = screen.snapshot()
            val center = TargetResolver.touchPoint(target, snapshot)
            val (from, to) = Gestures.swipe(center, arguments.get("direction").asString, arguments.distance)
            screen.injector.drag(from, to, snapshot.density, arguments.swipeDuration)
            JsonObject()
        },
        command(BuiltinCommands.edgeSwipe) { arguments ->
            val snapshot = screen.snapshot()
            val (from, to) = Gestures.edgeSwipe(snapshot.windowFrame, arguments.get("direction").asString, arguments.distance)
            screen.injector.drag(from, to, snapshot.density, arguments.swipeDuration)
            JsonObject()
        },
        command(BuiltinCommands.drag) { arguments ->
            val start = Target.parse(arguments)
            val end = Target.parse(arguments, prefix = "to_")
            if (start == Target.None || end == Target.None) {
                throw Target.invalid(
                    "The drag needs where it starts and where it ends",
                    hint = "Pass the start as ref, identifier, label, value, traits or x and y, and the end with the " +
                        "same arguments prefixed with to_, such as to_ref or to_x and to_y",
                )
            }
            val snapshot = screen.snapshot()
            val from = TargetResolver.touchPoint(start, snapshot)
            val to = TargetResolver.touchPoint(end, snapshot)
            screen.injector.drag(from, to, snapshot.density, arguments.double("duration") ?: DEFAULT_DRAG_SECONDS)
            JsonObject()
        },
        command(BuiltinCommands.typeText) { arguments ->
            val target = Target.parse(arguments)
            if (target != Target.None) {
                val snapshot = screen.snapshot()
                screen.injector.tap(TargetResolver.touchPoint(target, snapshot), snapshot.density, count = 1)
                // The tap can open a screen that focuses its field once it settles
                screen.idle.settle(FOCUS_SETTLE_SECONDS)
            }
            screen.injector.type(arguments.get("text").asString)
            JsonObject()
        },
        command(BuiltinCommands.pressKey) { arguments ->
            screen.injector.press(Keys.parse(arguments.get("key").asString))
            JsonObject()
        },
        command(BuiltinCommands.waitFor) { arguments ->
            val query = WaitCondition.query(Target.parse(arguments))
            val condition = WaitCondition.parse(arguments.get("condition")?.asString)
            val timeout = arguments.double("timeout") ?: DEFAULT_TIMEOUT_SECONDS
            withTimeoutOrNull((timeout * MILLIS_PER_SECOND).toLong()) {
                while (!condition.isMet(query, screen.snapshotOrNull())) delay(WAIT_POLL_MILLIS)
            } ?: throw condition.timedOut(query, timeout, WaitCondition.EXISTS.isMet(query, screen.snapshotOrNull()))
            JsonObject()
        },
        command(BuiltinCommands.waitForIdle) { arguments ->
            screen.idle.await(arguments.double("timeout") ?: DEFAULT_TIMEOUT_SECONDS)
            JsonObject()
        },
        command(BuiltinCommands.screenshot) { arguments ->
            val scale = arguments.double("scale") ?: 1.0
            if (scale <= 0 || scale > MAX_SCALE) throw Target.invalid("scale must be above 0 and up to $MAX_SCALE")
            val target = Target.parse(arguments)
            val snapshot = screen.snapshot()
            val frame = if (target == Target.None) null else TargetResolver.element(target, snapshot).frame
            AgentImage.png(screen.screenshots.png(frame, scale, snapshot.density))
        },
    )

    private fun command(descriptor: CommandDescriptor, run: suspend (JsonObject) -> JsonElement): WireCommand =
        object : WireCommand {
            override val descriptor = descriptor

            override suspend fun run(arguments: JsonObject): JsonElement = run(arguments)
        }

    private fun JsonObject.boolean(name: String) = get(name)?.asBoolean
    private fun JsonObject.int(name: String) = get(name)?.asInt
    private fun JsonObject.double(name: String) = get(name)?.asDouble
    private val JsonObject.distance get() = double("distance") ?: DEFAULT_SWIPE_DISTANCE
    private val JsonObject.swipeDuration get() = double("duration") ?: DEFAULT_SWIPE_SECONDS

    private companion object {
        const val DEFAULT_SWIPE_DISTANCE = 200.0
        const val DEFAULT_SWIPE_SECONDS = 0.2
        const val DEFAULT_LONG_PRESS_SECONDS = 2.0
        const val DEFAULT_DRAG_SECONDS = 0.5
        const val WAIT_POLL_MILLIS = 100L
        const val MILLIS_PER_SECOND = 1000
        const val DEFAULT_TIMEOUT_SECONDS = 10.0
        const val MAX_SCALE = 4.0
        const val FOCUS_SETTLE_SECONDS = 2.0
    }
}
