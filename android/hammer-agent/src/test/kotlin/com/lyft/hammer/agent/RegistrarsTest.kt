package com.lyft.hammer.agent

import org.assertj.core.api.Assertions.assertThat
import org.junit.Test

class RegistrarsTest {

    private val log = RecordingLog()

    @Test
    fun start_manualStart_registersTheManifestRegistrarsCommands() {
        val core = AgentCore(environment(mapOf(LIBRARY to { listOf(command("sign_in")) })), log)

        core.start(allowsReleaseBuild = false)

        assertThat(core.commands.map { it.name }).containsExactly("sign_in")
    }

    @Test
    fun start_withoutManifestRegistrars_skipsThem() {
        val core = AgentCore(environment(mapOf(LIBRARY to { listOf(command("sign_in")) })), log, readsManifestRegistrars = false)

        core.start(allowsReleaseBuild = false)

        assertThat(core.commands).isEmpty()
    }

    @Test
    fun start_brokenRegistrars_logsEachAndStartsWithTheOthers() {
        val environment = environment(
            mapOf(
                APP to { listOf(command("sign_in")) },
                LIBRARY to { throw IllegalStateException("No config") },
            ),
            extraKeys = listOf(MISSING),
        )
        val core = AgentCore(environment, log)

        core.start(allowsReleaseBuild = false)

        assertThat(environment.listens).containsExactly("hammer_com.example.app")
        assertThat(core.commands.map { it.name }).containsExactly("sign_in")
        assertThat(log.lines).containsExactly(
            "E Hammer agent skipped registrar $LIBRARY: it threw java.lang.IllegalStateException: No config",
            "E Hammer agent skipped registrar $MISSING: there is no such class",
            "I Hammer agent listening on @hammer_com.example.app, adb and this app can control it",
        )
    }

    @Test
    fun start_registrarCommandWithReservedName_skipsOnlyThatCommand() {
        val reserved = command("save", CommandDescriptor.Parameter("output", CommandDescriptor.ParameterType.StringValue, ""))
        val core = AgentCore(environment(mapOf(LIBRARY to { listOf(reserved, command("ping")) })), log)

        core.start(allowsReleaseBuild = false)

        assertThat(core.commands.map { it.name }).containsExactly("ping")
        assertThat(log.lines.first()).isEqualTo(
            "E Hammer agent skipped command save from $LIBRARY: Command save uses reserved parameter names: [output]",
        )
    }

    @Test
    fun start_commandRegisteredBeforeStart_survivesARegistrarsCommand() {
        val core = AgentCore(environment(mapOf(LIBRARY to { listOf(command("sign_in", summary = "Library.")) })), log)
        core.register(command("sign_in", summary = "App."))

        core.start(allowsReleaseBuild = false)

        assertThat(core.commands.map { it.summary }).containsExactly("App.")
        assertThat(log.lines.first()).isEqualTo("W Hammer agent skipped command sign_in from $LIBRARY; the app registered its own")
    }

    @Test
    fun register_afterStart_replacesARegistrarsCommand() {
        val core = AgentCore(environment(mapOf(LIBRARY to { listOf(command("sign_in", summary = "Library.")) })), log)
        core.start(allowsReleaseBuild = false)

        core.register(command("sign_in", summary = "App."))

        assertThat(core.commands.map { it.summary }).containsExactly("App.")
    }

    @Test
    fun start_severalRegistrars_registersThemInKeyOrder() {
        val core = AgentCore(
            environment(linkedMapOf(LIBRARY to { listOf(command("library")) }, APP to { listOf(command("app")) })),
            log,
        )

        core.start(allowsReleaseBuild = false)

        assertThat(core.commands.map { it.name }).containsExactly("app", "library")
    }

    @Test
    fun start_entryWithAnotherValue_isIgnored() {
        val environment = FakeEnvironment(
            manifestEntries = mapOf(REGISTRAR_KEY_PREFIX + APP to "true"),
            registrars = mapOf(APP to { listOf(command("sign_in")) }),
        )
        val core = AgentCore(environment, log)

        core.start(allowsReleaseBuild = false)

        assertThat(core.commands).isEmpty()
    }

    @Test
    fun start_againAfterStop_doesNotReadTheRegistrarsAgain() {
        var reads = 0
        val core = AgentCore(
            environment(
                mapOf(
                    APP to {
                        reads++
                        listOf(command("sign_in"))
                    },
                ),
            ),
            log,
        )
        core.start(allowsReleaseBuild = false)
        core.stop()

        core.start(allowsReleaseBuild = false)

        assertThat(reads).isEqualTo(1)
    }

    private fun environment(registrars: Map<String, () -> List<AgentCommand>>, extraKeys: List<String> = emptyList()) =
        FakeEnvironment(
            manifestEntries = (registrars.keys + extraKeys).associate { REGISTRAR_KEY_PREFIX + it to REGISTRAR_MARKER },
            registrars = registrars,
        )

    private fun command(name: String, vararg parameters: CommandDescriptor.Parameter, summary: String = ""): AgentCommand =
        object : AgentCommand {
            override val descriptor = CommandDescriptor(name, summary, parameters.toList())

            override suspend fun run(arguments: JsonValue.Object, context: AgentContext): JsonValue = JsonValue.Object()
        }

    private companion object {
        const val APP = "com.example.app.DebugCommands"
        const val LIBRARY = "com.example.library.LibraryCommands"
        const val MISSING = "com.example.library.Removed"
    }
}
