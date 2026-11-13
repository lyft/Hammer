package com.lyft.hammer.agent

import com.lyft.hammer.agent.core.WireCommand
import java.io.IOException

internal class FakeEnvironment(
    override val isDebuggable: Boolean = true,
    override val manifestEntries: Map<String, String> = emptyMap(),
    override val otherProcessName: String? = null,
    private val socketTaken: Boolean = false,
    private val builtins: List<WireCommand> = emptyList(),
    private val registrars: Map<String, () -> List<AgentCommand>> = emptyMap(),
    override val listeningSockets: ListeningSockets = ListeningSockets(),
) : AgentEnvironment {
    override val socketName = "hammer_com.example.app"
    val listens = mutableListOf<String>()
    var closes = 0

    override fun builtinCommands(): List<WireCommand> = builtins

    override fun wire(command: AgentCommand): WireCommand = object : WireCommand {
        override val descriptor = command.descriptor

        override suspend fun run(arguments: JsonValue.Object): JsonValue =
            command.run(arguments, AgentContext(error("No screen in unit tests")))
    }

    override fun registrarCommands(className: String): List<AgentCommand> =
        registrars[className]?.invoke() ?: throw RegistrarError("there is no such class")

    override fun listen(socketName: String, handler: ConnectionHandler): AgentListener {
        if (socketTaken) throw IOException("Address already in use")
        listens += socketName
        return AgentListener { closes++ }
    }
}
