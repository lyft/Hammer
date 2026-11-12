package com.lyft.hammer.agent

import com.google.gson.JsonElement
import com.google.gson.JsonObject
import com.google.gson.JsonParser
import com.lyft.hammer.agent.core.WireCommand
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.async
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.Test

class CommandRegistryTest {

    private val log = RecordingLog()
    private val registry = CommandRegistry(log)

    @Test
    fun register_appCommandWithBuiltinName_replacesItInItsPosition() {
        registry.register(command("tap", "Built-in tap."), CommandSource.BUILTIN, CommandRegistry.BUILTIN_ORIGIN)
        registry.register(command("swipe", "Built-in swipe."), CommandSource.BUILTIN, CommandRegistry.BUILTIN_ORIGIN)

        registry.register(command("tap", "App tap."), CommandSource.APP, CommandRegistry.APP_ORIGIN)

        assertThat(registry.descriptors.map { it.summary }).containsExactly("App tap.", "Built-in swipe.")
        assertThat(log.lines).isEmpty()
    }

    @Test
    fun register_registrarCommandWithAppName_keepsTheAppsAndLogsTheSkip() {
        registry.register(command("sign_in", "App sign in."), CommandSource.APP, CommandRegistry.APP_ORIGIN)

        registry.register(command("sign_in", "Library sign in."), CommandSource.REGISTRAR, "com.example.LibraryCommands")

        assertThat(registry.descriptors.map { it.summary }).containsExactly("App sign in.")
        assertThat(log.lines).containsExactly(
            "W Hammer agent skipped command sign_in from com.example.LibraryCommands; the app registered its own",
        )
    }

    @Test
    fun register_appCommandAfterRegistrar_replacesTheRegistrars() {
        registry.register(command("sign_in", "Library sign in."), CommandSource.REGISTRAR, "com.example.LibraryCommands")

        registry.register(command("sign_in", "App sign in."), CommandSource.APP, CommandRegistry.APP_ORIGIN)

        assertThat(registry.descriptors.map { it.summary }).containsExactly("App sign in.")
        assertThat(log.lines).isEmpty()
    }

    @Test
    fun register_registrarCommandWithBuiltinName_replacesItAndLogsIt() {
        registry.register(command("tap", "Built-in tap."), CommandSource.BUILTIN, CommandRegistry.BUILTIN_ORIGIN)

        registry.register(command("tap", "Library tap."), CommandSource.REGISTRAR, "com.example.LibraryCommands")

        assertThat(registry.descriptors.map { it.summary }).containsExactly("Library tap.")
        assertThat(log.lines).containsExactly(
            "W Hammer agent command tap from com.example.LibraryCommands replaces the one from the built-in commands",
        )
    }

    @Test
    fun register_reservedParameterName_throwsAndKeepsTheRegistry() {
        val command = command("save", "", CommandDescriptor.Parameter("output", CommandDescriptor.ParameterType.StringValue, ""))

        assertThatThrownBy { registry.register(command, CommandSource.APP, CommandRegistry.APP_ORIGIN) }
            .isInstanceOf(IllegalArgumentException::class.java)
            .hasMessage("Command save uses reserved parameter names: [output]")
        assertThat(registry.descriptors).isEmpty()
    }

    @Test
    fun register_whileACommandRuns_isListedRightAway() = runTest {
        val release = CompletableDeferred<Unit>()
        registry.register(
            command("slow", "") {
                release.await()
                JsonObject()
            },
            CommandSource.BUILTIN,
            CommandRegistry.BUILTIN_ORIGIN,
        )
        val router = CommandRouter(registry)
        val running = async { router.respond(HttpRequest("POST", "/commands/slow", emptyMap(), ByteArray(0))) }
        runCurrent()

        registry.register(command("ping", "Pings."), CommandSource.APP, CommandRegistry.APP_ORIGIN)
        val commands = router.respond(HttpRequest("GET", "/commands", emptyMap(), ByteArray(0)))

        assertThat(running.isActive).isTrue()
        assertThat(JsonParser.parseString(commands.body).asJsonArray.map { it.asJsonObject["name"].asString })
            .containsExactly("slow", "ping")
        release.complete(Unit)
        assertThat(running.await().status).isEqualTo(200)
    }

    private fun command(
        name: String,
        summary: String,
        vararg parameters: CommandDescriptor.Parameter,
        run: suspend () -> JsonElement = { JsonObject() },
    ): WireCommand = object : WireCommand {
        override val descriptor = CommandDescriptor(name, summary, parameters.toList())

        override suspend fun run(arguments: JsonObject): JsonElement = run()
    }
}
