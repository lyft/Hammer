package com.lyft.hammer.agent

import com.lyft.hammer.agent.core.WireCommand

/** Where a command came from, which decides what replaces what when two have the same name. */
internal enum class CommandSource {
    BUILTIN,
    REGISTRAR,
    APP,
}

/**
 * The commands the agent runs, safe to change while requests are served. A command replaces one with
 * the same name and keeps its position, except that a registrar's command never replaces the app's own.
 */
internal class CommandRegistry(private val log: AgentLog) {

    private class Registration(val command: WireCommand, val source: CommandSource, val origin: String)

    private val registrations = LinkedHashMap<String, Registration>()

    val descriptors: List<CommandDescriptor>
        @Synchronized get() = registrations.values.map { it.command.descriptor }

    val names: List<String>
        @Synchronized get() = registrations.keys.toList()

    @Synchronized
    fun command(name: String): WireCommand? = registrations[name]?.command

    /**
     * Adds [command], from [origin] such as a registrar's class name.
     *
     * @throws IllegalArgumentException if it uses a reserved parameter name or one parameter twice.
     */
    @Synchronized
    fun register(command: WireCommand, source: CommandSource, origin: String) {
        val descriptor = command.descriptor
        validate(descriptor)
        val existing = registrations[descriptor.name]
        if (source == CommandSource.REGISTRAR && existing != null) {
            if (existing.source == CommandSource.APP) {
                log.warning("Hammer agent skipped command ${descriptor.name} from $origin; the app registered its own")
                return
            }
            log.warning("Hammer agent command ${descriptor.name} from $origin replaces the one from ${existing.origin}")
        }
        registrations[descriptor.name] = Registration(command, source, origin)
    }

    private fun validate(descriptor: CommandDescriptor) {
        val names = descriptor.parameters.map { it.name }
        val reserved = names.filter { it in CommandDescriptor.reservedParameterNames }
        require(reserved.isEmpty()) { "Command ${descriptor.name} uses reserved parameter names: $reserved" }
        require(names.toSet().size == names.size) { "Command ${descriptor.name} has duplicate parameters: $names" }
    }

    companion object {
        const val BUILTIN_ORIGIN = "the built-in commands"
        const val APP_ORIGIN = "the app"

        fun of(commands: List<WireCommand>, log: AgentLog): CommandRegistry = CommandRegistry(log).apply {
            commands.forEach { register(it, CommandSource.BUILTIN, BUILTIN_ORIGIN) }
        }
    }
}
