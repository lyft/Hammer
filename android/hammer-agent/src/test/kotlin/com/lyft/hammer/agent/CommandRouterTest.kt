package com.lyft.hammer.agent

import com.google.gson.JsonElement
import com.google.gson.JsonObject
import com.google.gson.JsonParser
import com.lyft.hammer.agent.core.WireCommand
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitCancellation
import kotlinx.coroutines.cancelAndJoin
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.Test

class CommandRouterTest {

    private val signIn = StubCommand(
        CommandDescriptor(
            name = "sign_in",
            summary = "Signs in.",
            parameters = listOf(CommandDescriptor.Parameter("user", CommandDescriptor.ParameterType.StringValue, "The user.", isRequired = true)),
        ),
    ) { JsonParser.parseString("""{"zeta": 1, "alpha": {"b": 2, "a": 1}}""") }

    @Test
    fun respond_getCommands_listsDescriptorsInRegistrationOrder() = runTest {
        val router = CommandRouter(listOf(signIn, StubCommand(CommandDescriptor("ping", "Pings."))))

        val response = router.respond(request("GET", "/commands"))

        assertThat(response.status).isEqualTo(200)
        assertThat(JsonParser.parseString(response.body).asJsonArray.map { it.asJsonObject["name"].asString })
            .containsExactly("sign_in", "ping")
    }

    @Test
    fun respond_postCommand_runsItWithArgumentsAndSortsOutputKeys() = runTest {
        val router = CommandRouter(listOf(signIn))

        val response = router.respond(request("POST", "/commands/sign_in", """{"user": "test"}"""))

        assertThat(response.status).isEqualTo(200)
        assertThat(response.body).isEqualTo("""{"alpha":{"a":1,"b":2},"zeta":1}""")
        assertThat(signIn.calls).containsExactly(JsonParser.parseString("""{"user": "test"}""").asJsonObject)
    }

    @Test
    fun respond_emptyBody_runsWithNoArguments() = runTest {
        val ping = StubCommand(CommandDescriptor("ping", "Pings."))

        val response = CommandRouter(listOf(ping)).respond(request("POST", "/commands/ping"))

        assertThat(response.status).isEqualTo(200)
        assertThat(response.body).isEqualTo("{}")
        assertThat(ping.calls).containsExactly(JsonObject())
    }

    @Test
    fun respond_unknownCommandNearName_suggestsIt() = runTest {
        val response = CommandRouter(listOf(signIn)).respond(request("POST", "/commands/sign_on", "{}"))

        assertThat(response.status).isEqualTo(404)
        assertThat(response.body).isEqualTo(
            """{"error":"Unknown command \"sign_on\", did you mean sign_in?","code":"unknown_command","hint":"The commands are sign_in"}""",
        )
    }

    @Test
    fun respond_unknownRoute_isInvalidRequest() = runTest {
        val response = CommandRouter(listOf(signIn)).respond(request("GET", "/status"))

        assertThat(response.status).isEqualTo(404)
        assertThat(response.body).isEqualTo("""{"error":"Unknown route GET /status","code":"invalid_request"}""")
    }

    @Test
    fun respond_missingRequiredArgument_isInvalidArgumentsWithoutRunning() = runTest {
        val response = CommandRouter(listOf(signIn)).respond(request("POST", "/commands/sign_in", "{}"))

        assertThat(response.status).isEqualTo(400)
        assertThat(response.body).isEqualTo(
            """{"error":"Missing required argument \"user\" for sign_in, expected a string",""" +
                """"code":"invalid_arguments","hint":"sign_in takes user (required): a string"}""",
        )
        assertThat(signIn.calls).isEmpty()
    }

    @Test
    fun respond_bodyNotObject_isInvalidArguments() = runTest {
        val response = CommandRouter(listOf(signIn)).respond(request("POST", "/commands/sign_in", "[1]"))

        assertThat(response.status).isEqualTo(400)
        assertThat(response.body).contains("\"error\":\"The arguments must be a JSON object\"")
    }

    @Test
    fun respond_malformedBody_isInvalidArguments() = runTest {
        val response = CommandRouter(listOf(signIn)).respond(request("POST", "/commands/sign_in", "{"))

        assertThat(response.status).isEqualTo(400)
        assertThat(response.body).contains("\"code\":\"invalid_arguments\"")
    }

    @Test
    fun respond_agentErrorWithCustomCode_isServerErrorWithCodeAndHint() = runTest {
        val failing = StubCommand(CommandDescriptor("ping", "")) { throw AgentError("No user", code = "unknown_user", hint = "Use test") }

        val response = CommandRouter(listOf(failing)).respond(request("POST", "/commands/ping"))

        assertThat(response.status).isEqualTo(500)
        assertThat(response.body).isEqualTo("""{"error":"No user","code":"unknown_user","hint":"Use test"}""")
    }

    @Test
    fun respond_agentErrorWithInvalidArguments_isBadRequest() = runTest {
        val failing = StubCommand(CommandDescriptor("ping", "")) { throw AgentError("Bad value", code = AgentErrorCode.INVALID_ARGUMENTS) }

        assertThat(CommandRouter(listOf(failing)).respond(request("POST", "/commands/ping")).status).isEqualTo(400)
    }

    @Test
    fun respond_unexpectedException_isFailed() = runTest {
        val failing = StubCommand(CommandDescriptor("ping", "")) { throw IllegalStateException("Boom") }

        val response = CommandRouter(listOf(failing)).respond(request("POST", "/commands/ping"))

        assertThat(response.status).isEqualTo(500)
        assertThat(response.body).isEqualTo("""{"error":"Boom","code":"failed"}""")
    }

    @Test
    fun respond_twoCommandsAtOnce_runsThemOneAtATime() = runTest {
        val release = CompletableDeferred<Unit>()
        val slow = StubCommand(CommandDescriptor("slow", "")) {
            release.await()
            JsonObject()
        }
        val fast = StubCommand(CommandDescriptor("fast", ""))
        val router = CommandRouter(listOf(slow, fast))

        val slowResponse = async { router.respond(request("POST", "/commands/slow")) }
        runCurrent()
        val fastResponse = async { router.respond(request("POST", "/commands/fast")) }
        runCurrent()

        assertThat(fast.calls).isEmpty()
        release.complete(Unit)
        assertThat(slowResponse.await().status).isEqualTo(200)
        assertThat(fastResponse.await().status).isEqualTo(200)
        assertThat(fast.calls).hasSize(1)
    }

    @Test
    fun respond_cancelledWhileCommandRuns_isCancelledWithoutResponding() = runTest {
        val hang = StubCommand(CommandDescriptor("hang", "")) { awaitCancellation() }
        val router = CommandRouter(listOf(hang))
        var response: HttpResponse? = null

        val job = launch { response = router.respond(request("POST", "/commands/hang")) }
        runCurrent()
        job.cancelAndJoin()

        assertThat(hang.calls).hasSize(1)
        assertThat(response).isNull()
    }

    @Test
    fun init_reservedParameterName_throws() {
        val command = StubCommand(
            CommandDescriptor("save", "", listOf(CommandDescriptor.Parameter("output", CommandDescriptor.ParameterType.StringValue, ""))),
        )

        assertThatThrownBy { CommandRouter(listOf(command)) }
            .isInstanceOf(IllegalArgumentException::class.java)
            .hasMessage("Command save uses reserved parameter names: [output]")
    }

    @Test
    fun init_androidOptionName_throws() {
        val command = StubCommand(
            CommandDescriptor("open", "", listOf(CommandDescriptor.Parameter("app_id", CommandDescriptor.ParameterType.StringValue, ""))),
        )

        assertThatThrownBy { CommandRouter(listOf(command)) }
            .isInstanceOf(IllegalArgumentException::class.java)
            .hasMessage("Command open uses reserved parameter names: [app_id]")
    }

    @Test
    fun init_sameNameTwice_keepsLastAndFirstPosition() = runTest {
        val first = StubCommand(CommandDescriptor("ping", "First."))
        val second = StubCommand(CommandDescriptor("ping", "Second."))

        val router = CommandRouter(listOf(first, signIn, second))
        router.respond(request("POST", "/commands/ping"))

        assertThat(router.descriptors.map { it.summary }).containsExactly("Second.", "Signs in.")
        assertThat(first.calls).isEmpty()
        assertThat(second.calls).hasSize(1)
    }

    private fun request(method: String, path: String, body: String = "") =
        HttpRequest(method, path, emptyMap(), body.toByteArray())

    private class StubCommand(
        override val descriptor: CommandDescriptor,
        private val output: suspend () -> JsonElement = { JsonObject() },
    ) : WireCommand {
        val calls = mutableListOf<JsonObject>()

        override suspend fun run(arguments: JsonObject): JsonElement {
            calls += arguments
            return output()
        }
    }
}
