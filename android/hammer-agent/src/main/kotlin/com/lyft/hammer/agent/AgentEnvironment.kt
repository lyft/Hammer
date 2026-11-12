package com.lyft.hammer.agent

import com.lyft.hammer.agent.core.WireCommand
import java.io.IOException

/** What the agent needs from the app and the device, so its start rules run in unit tests. */
internal interface AgentEnvironment {
    val socketName: String

    /** The sockets this process's agents listen on. */
    val listeningSockets: ListeningSockets

    val isDebuggable: Boolean

    /** The `<meta-data>` entries of the app's `<application>`, as strings. */
    val manifestEntries: Map<String, String>

    /** The process name when it isn't the app's main process, null in the main process. */
    val otherProcessName: String?

    fun builtinCommands(): List<WireCommand>

    /** Adapts an app's command to the router. */
    fun wire(command: AgentCommand): WireCommand

    /**
     * Creates the registrar named [className] and returns its commands.
     *
     * @throws RegistrarError if the class can't be a registrar, or whatever the registrar throws.
     */
    fun registrarCommands(className: String): List<AgentCommand>

    /** @throws IOException if the socket is taken. */
    fun listen(socketName: String, handler: ConnectionHandler): AgentListener
}

internal fun interface AgentListener {
    fun close()
}

/** Why a class named in the manifest can't be a registrar, such as `isn't a HammerCommandRegistrar`. */
internal class RegistrarError(val problem: String) : Exception(problem)
