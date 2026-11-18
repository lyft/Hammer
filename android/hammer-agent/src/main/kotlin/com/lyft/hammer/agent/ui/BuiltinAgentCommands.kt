package com.lyft.hammer.agent.ui

import com.lyft.hammer.agent.CommandDescriptor
import com.lyft.hammer.agent.JsonValue
import com.lyft.hammer.agent.core.AgentImage
import com.lyft.hammer.agent.core.BuiltinCommands
import com.lyft.hammer.agent.core.WireCommand
import com.lyft.hammer.agent.core.emptyJsonObject
import kotlinx.coroutines.delay
import kotlinx.coroutines.withTimeoutOrNull

/** The built-in commands the Android agent runs, with the behavior Hammer's commands reference describes. */
internal class BuiltinAgentCommands(private val screen: AgentScreen) {

    private val runs: Map<CommandDescriptor, suspend (JsonValue.Object) -> JsonValue> = mapOf(
        BuiltinCommands.describe to { arguments ->
            DescribeOutput.json(screen.snapshot(), all = arguments.boolean("all") ?: false)
        },
        BuiltinCommands.tap to { arguments ->
            val count = arguments.int("count") ?: 1
            if (count < 1) throw Target.invalid("count must be at least 1")
            val target = Target.parse(arguments)
            val snapshot = screen.snapshot()
            screen.injector.tap(TargetResolver.touchPoint(target, snapshot), snapshot.density, count)
            emptyJsonObject
        },
        BuiltinCommands.longPress to { arguments ->
            val target = Target.parse(arguments)
            val snapshot = screen.snapshot()
            val point = TargetResolver.touchPoint(target, snapshot)
            screen.injector.longPress(point, snapshot.density, arguments.double("duration") ?: DEFAULT_LONG_PRESS_SECONDS)
            emptyJsonObject
        },
        BuiltinCommands.swipe to { arguments ->
            val target = Target.parse(arguments)
            val snapshot = screen.snapshot()
            val center = TargetResolver.touchPoint(target, snapshot)
            val (from, to) = Gestures.swipe(center, arguments.string("direction"), arguments.distance)
            screen.injector.drag(from, to, snapshot.density, arguments.swipeDuration)
            emptyJsonObject
        },
        BuiltinCommands.edgeSwipe to { arguments ->
            val snapshot = screen.snapshot()
            val (from, to) = Gestures.edgeSwipe(snapshot.windowFrame, arguments.string("direction"), arguments.distance)
            screen.injector.drag(from, to, snapshot.density, arguments.swipeDuration)
            emptyJsonObject
        },
        BuiltinCommands.drag to { arguments ->
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
            emptyJsonObject
        },
        BuiltinCommands.pinch to { arguments ->
            val target = Target.parse(arguments)
            val snapshot = screen.snapshot()
            val (from, to) = Gestures.pinch(
                center = TargetResolver.touchPoint(target, snapshot),
                scale = checkNotNull(arguments.double("scale")) { "Missing scale" },
                distance = arguments.double("distance") ?: DEFAULT_PINCH_DISTANCE,
            )
            screen.injector.pinch(from, to, snapshot.density, arguments.double("duration") ?: DEFAULT_PINCH_SECONDS)
            emptyJsonObject
        },
        BuiltinCommands.typeText to { arguments ->
            val target = Target.parse(arguments)
            if (target != Target.None) {
                val snapshot = screen.snapshot()
                screen.injector.tap(TargetResolver.touchPoint(target, snapshot), snapshot.density, count = 1)
                // The tap can open a screen that focuses its field once it settles
                screen.idle.settle(FOCUS_SETTLE_SECONDS)
            }
            screen.injector.type(arguments.string("text"))
            emptyJsonObject
        },
        BuiltinCommands.pressKey to { arguments ->
            screen.injector.press(Keys.parse(arguments.string("key")))
            emptyJsonObject
        },
        BuiltinCommands.waitFor to { arguments ->
            val query = WaitCondition.query(Target.parse(arguments))
            val condition = WaitCondition.parse(arguments["condition"]?.stringValue)
            val timeout = arguments.double("timeout") ?: DEFAULT_TIMEOUT_SECONDS
            withTimeoutOrNull((timeout * MILLIS_PER_SECOND).toLong()) {
                while (!condition.isMet(query, screen.snapshotOrNull())) delay(WAIT_POLL_MILLIS)
            } ?: throw condition.timedOut(query, timeout, WaitCondition.EXISTS.isMet(query, screen.snapshotOrNull()))
            emptyJsonObject
        },
        BuiltinCommands.waitForIdle to { arguments ->
            screen.idle.await(arguments.double("timeout") ?: DEFAULT_TIMEOUT_SECONDS)
            emptyJsonObject
        },
        BuiltinCommands.screenshot to { arguments ->
            val scale = arguments.double("scale") ?: 1.0
            if (scale <= 0 || scale > MAX_SCALE) throw Target.invalid("scale must be above 0 and up to $MAX_SCALE")
            val target = Target.parse(arguments)
            val snapshot = screen.snapshot()
            val frame = if (target == Target.None) null else TargetResolver.element(target, snapshot).frame
            AgentImage.png(screen.screenshots.png(frame, scale, snapshot.density))
        },
    )

    /** The commands in [BuiltinCommands.all]'s order, which the contract with Hammer fixes. */
    val all: List<WireCommand> = BuiltinCommands.all.map { command(it, runs.getValue(it)) }

    private fun command(descriptor: CommandDescriptor, run: suspend (JsonValue.Object) -> JsonValue): WireCommand =
        object : WireCommand {
            override val descriptor = descriptor

            override suspend fun run(arguments: JsonValue.Object): JsonValue = run(arguments)
        }

    private fun JsonValue.Object.boolean(name: String) = get(name)?.boolValue
    private fun JsonValue.Object.int(name: String) = get(name)?.numberValue?.toInt()
    private fun JsonValue.Object.double(name: String) = get(name)?.numberValue

    // Validation has checked that a required argument is there and has its type
    private fun JsonValue.Object.string(name: String) = checkNotNull(get(name)?.stringValue) { "Missing $name" }
    private val JsonValue.Object.distance get() = double("distance") ?: DEFAULT_SWIPE_DISTANCE
    private val JsonValue.Object.swipeDuration get() = double("duration") ?: DEFAULT_SWIPE_SECONDS

    private companion object {
        const val DEFAULT_SWIPE_DISTANCE = 200.0
        const val DEFAULT_SWIPE_SECONDS = 0.2
        const val DEFAULT_LONG_PRESS_SECONDS = 2.0
        const val DEFAULT_DRAG_SECONDS = 0.5
        const val DEFAULT_PINCH_DISTANCE = 200.0
        const val DEFAULT_PINCH_SECONDS = 0.5
        const val WAIT_POLL_MILLIS = 100L
        const val MILLIS_PER_SECOND = 1000
        const val DEFAULT_TIMEOUT_SECONDS = 10.0
        const val MAX_SCALE = 4.0
        const val FOCUS_SETTLE_SECONDS = 2.0
    }
}
