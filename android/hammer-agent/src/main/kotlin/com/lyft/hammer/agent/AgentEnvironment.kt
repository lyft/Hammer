package com.lyft.hammer.agent

import com.lyft.hammer.agent.core.WireCommand
import java.io.IOException

/** What the agent needs from the app and the device, so its start rules run in unit tests. */
internal interface AgentEnvironment {
    val socketName: String

    val isDebuggable: Boolean

    /** The `<meta-data>` entries of the app's `<application>`, as strings. */
    val manifestEntries: Map<String, String>

    /** The process name when it isn't the app's main process, null in the main process. */
    val otherProcessName: String?

    fun builtinCommands(): List<WireCommand>

    /** Adapts an app's command to the router. */
    fun wire(command: AgentCommand): WireCommand

    /** @throws IOException if the socket is taken. */
    fun listen(socketName: String, handler: ConnectionHandler): AgentListener
}

internal fun interface AgentListener {
    fun close()
}
