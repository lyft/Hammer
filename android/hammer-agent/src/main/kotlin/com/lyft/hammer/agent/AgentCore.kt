package com.lyft.hammer.agent

import java.io.IOException

/** The prefix of the `<meta-data>` keys that name registrars, followed by the class name. */
internal const val REGISTRAR_KEY_PREFIX = "com.lyft.hammer.agent.commands:"

/** The value of a registrar's `<meta-data>` entry. */
internal const val REGISTRAR_MARKER = "com.lyft.hammer.agent.HammerCommandRegistrar"

/** [HammerAgent]'s behavior, on an [AgentEnvironment]. */
internal class AgentCore(
    private val environment: AgentEnvironment,
    private val log: AgentLog,
    private var readsManifestRegistrars: Boolean = true,
) {

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
        if (readsManifestRegistrars) {
            readsManifestRegistrars = false
            registerManifestRegistrars()
        }
        val socketName = environment.socketName
        listener = try {
            environment.listen(socketName, ConnectionHandler(CommandRouter(registry)))
        } catch (exception: IOException) {
            throw AgentStartError.SocketUnavailable(socketName, exception, heldByThisProcess = environment.listeningSockets.contains(socketName))
        }
        environment.listeningSockets.add(socketName)
        log.info("Hammer agent listening on @$socketName, adb and this app can control it")
        return true
    }

    // A broken entry, often a library's, must not keep the app's own commands and start() from working
    private fun registerManifestRegistrars() {
        val classNames = environment.manifestEntries
            .filter { (key, value) -> key.startsWith(REGISTRAR_KEY_PREFIX) && value == REGISTRAR_MARKER }
            .keys.sorted().map { it.removePrefix(REGISTRAR_KEY_PREFIX) }
        for (className in classNames) {
            val commands = try {
                environment.registrarCommands(className)
            } catch (error: RegistrarError) {
                log.error("Hammer agent skipped registrar $className: ${error.problem}")
                continue
            } catch (exception: Exception) {
                log.error("Hammer agent skipped registrar $className: it threw $exception", exception)
                continue
            } catch (error: LinkageError) {
                log.error("Hammer agent skipped registrar $className: it threw $error", error)
                continue
            }
            for (command in commands) {
                try {
                    registry.register(environment.wire(command), CommandSource.REGISTRAR, className)
                } catch (exception: IllegalArgumentException) {
                    log.error("Hammer agent skipped command ${command.descriptor.name} from $className: ${exception.message}")
                }
            }
        }
    }

    @Synchronized
    fun stop() {
        if (listener != null) environment.listeningSockets.remove(environment.socketName)
        listener?.close()
        listener = null
    }
}
