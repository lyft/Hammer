package com.lyft.hammer.agent

import java.io.IOException

/** [HammerAgent]'s behavior, on an [AgentEnvironment]. */
internal class AgentCore(private val environment: AgentEnvironment, private val log: AgentLog) {

    private val registry = CommandRegistry.of(environment.builtinCommands(), log)
    private var listener: AgentListener? = null

    val commands: List<CommandDescriptor>
        get() = registry.descriptors

    fun register(command: AgentCommand) {
        registry.register(environment.wire(command), CommandSource.APP, CommandRegistry.APP_ORIGIN)
    }

    /** @return whether the agent is listening. */
    @Synchronized
    fun start(allowsReleaseBuild: Boolean): Boolean {
        if (listener != null) return true
        // The socket name has no process part, so another process, such as :remote, would take it
        environment.otherProcessName?.let { process ->
            log.warning("Hammer agent didn't start in process $process; it runs only in the app's main process")
            return false
        }
        if (!environment.isDebuggable && !allowsReleaseBuild) throw AgentStartError.ReleaseBuild()
        val socketName = environment.socketName
        listener = try {
            environment.listen(socketName, ConnectionHandler(CommandRouter(registry)))
        } catch (exception: IOException) {
            throw AgentStartError.SocketUnavailable(socketName, exception)
        }
        log.info("Hammer agent listening on @$socketName, adb and this app can control it")
        return true
    }

    @Synchronized
    fun stop() {
        listener?.close()
        listener = null
    }
}
