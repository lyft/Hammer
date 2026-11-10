package com.lyft.hammer.agent

import com.google.gson.JsonElement
import com.google.gson.JsonObject
import com.lyft.hammer.agent.core.WireCommand
import com.lyft.hammer.agent.core.toGson
import com.lyft.hammer.agent.core.toJsonValue
import java.io.IOException

internal class FakeEnvironment(
    override val isDebuggable: Boolean = true,
    override val manifestEntries: Map<String, String> = emptyMap(),
    override val otherProcessName: String? = null,
    private val socketTaken: Boolean = false,
    private val builtins: List<WireCommand> = emptyList(),
) : AgentEnvironment {
    override val socketName = "hammer_com.example.app"
    val listens = mutableListOf<String>()
    var closes = 0

    override fun builtinCommands(): List<WireCommand> = builtins

    override fun wire(command: AgentCommand): WireCommand = object : WireCommand {
        override val descriptor = command.descriptor

        override suspend fun run(arguments: JsonObject): JsonElement =
            command.run(arguments.toJsonValue(), AgentContext(error("No screen in unit tests"))).toGson()
    }

    override fun listen(socketName: String, handler: ConnectionHandler): AgentListener {
        if (socketTaken) throw IOException("Address already in use")
        listens += socketName
        return AgentListener { closes++ }
    }
}
