package com.lyft.hammer.agent

import com.google.gson.JsonElement
import com.google.gson.JsonObject
import com.lyft.hammer.agent.core.AgentCommand
import com.lyft.hammer.agent.core.CommandDescriptor
import kotlinx.coroutines.test.runTest
import org.assertj.core.api.Assertions.assertThat
import org.junit.Test
import java.io.ByteArrayOutputStream

class ConnectionHandlerTest {

    private val tap = CountingCommand(CommandDescriptor("tap", "Taps."))
    private val handler = ConnectionHandler(CommandRouter(listOf(tap)))

    @Test
    fun respond_allowedPeer_writesRouterResponse() = runTest {
        val output = respond("GET /commands HTTP/1.1\r\nHost: 127.0.0.1:51234\r\n\r\n", peerUid = 2000)

        assertThat(output).startsWith("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n")
        assertThat(output).endsWith("Connection: close\r\n\r\n" + """[{"name":"tap","summary":"Taps.","parameters":[],"examples":[]}]""")
    }

    @Test
    fun respond_clientStillConnected_runsTheCommand() = runTest {
        val output = respond(TAP_REQUEST, peerUid = 2000, isClientGone = false)

        assertThat(output).startsWith("HTTP/1.1 200 OK\r\n")
        assertThat(tap.runs).isEqualTo(1)
    }

    @Test
    fun respond_clientGoneBeforeRunning_dropsTheCommand() = runTest {
        val output = respond(TAP_REQUEST, peerUid = 2000, isClientGone = true)

        assertThat(output).isEmpty()
        assertThat(tap.runs).isEqualTo(0)
    }

    @Test
    fun respond_otherApp_isForbidden() = runTest {
        val output = respond("GET /commands HTTP/1.1\r\n\r\n", peerUid = 10456)

        assertThat(output).startsWith("HTTP/1.1 403 Forbidden\r\n")
        assertThat(output).endsWith("""{"error":"Connections from uid 10456 are not allowed","code":"invalid_request",""" +
            """"hint":"Connect through adb forward, such as with the hammer command line tool"}""")
    }

    @Test
    fun respond_browserRequest_isForbidden() = runTest {
        val output = respond("GET /commands HTTP/1.1\r\nOrigin: https://example.com\r\n\r\n", peerUid = 2000)

        assertThat(output).startsWith("HTTP/1.1 403 Forbidden\r\n")
    }

    @Test
    fun respond_malformedRequest_isBadRequest() = runTest {
        val output = respond("GET\r\n\r\n", peerUid = 2000)

        assertThat(output).startsWith("HTTP/1.1 400 Bad Request\r\n")
        assertThat(output).endsWith("""{"error":"Invalid request line","code":"invalid_request"}""")
    }

    private suspend fun respond(raw: String, peerUid: Int, isClientGone: Boolean = false): String {
        val output = ByteArrayOutputStream()
        handler.respond(raw.byteInputStream(), output, peerUid, ownUid = 10123) { isClientGone }
        return output.toString(Charsets.UTF_8.name())
    }

    private class CountingCommand(override val descriptor: CommandDescriptor) : AgentCommand {
        var runs = 0

        override suspend fun run(arguments: JsonObject): JsonElement {
            runs += 1
            return JsonObject()
        }
    }

    private companion object {
        const val TAP_REQUEST = "POST /commands/tap HTTP/1.1\r\nContent-Type: application/json\r\nContent-Length: 2\r\n\r\n{}"
    }
}
