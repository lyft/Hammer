package com.lyft.hammer.system

import com.lyft.hammer.agent.CommandDescriptor
import com.lyft.hammer.agent.JsonValue
import com.lyft.hammer.agent.core.WireCommand
import com.lyft.hammer.agent.core.emptyJsonObject
import kotlinx.coroutines.test.runTest
import org.assertj.core.api.Assertions.assertThat
import org.junit.Test
import java.io.ByteArrayOutputStream

class SystemServerTest {

    private var taps = 0
    private val tap = object : WireCommand {
        override val descriptor = CommandDescriptor("tap", "Taps.")

        override suspend fun run(arguments: JsonValue.Object): JsonValue {
            taps++
            return emptyJsonObject
        }
    }

    @Test
    fun handler_anotherAppsUid_isRefusedWithoutRunningTheCommand() = runTest {
        val output = respond(TAP_REQUEST, peerUid = OTHER_APP_UID)

        assertThat(output).startsWith("HTTP/1.1 403 Forbidden\r\n")
        assertThat(output).contains("Connections from uid $OTHER_APP_UID are not allowed")
        assertThat(taps).isEqualTo(0)
    }

    @Test
    fun handler_adbShell_runsTheCommand() = runTest {
        val output = respond(TAP_REQUEST, peerUid = SHELL_UID)

        assertThat(output).startsWith("HTTP/1.1 200 OK\r\n")
        assertThat(taps).isEqualTo(1)
    }

    private suspend fun respond(request: String, peerUid: Int): String {
        val output = ByteArrayOutputStream()
        SystemServer.handler(listOf(tap)).respond(request.byteInputStream(), output, peerUid, HELPER_UID) { false }
        return output.toString(Charsets.UTF_8.name())
    }

    private companion object {
        const val SHELL_UID = 2000
        const val HELPER_UID = 10228
        const val OTHER_APP_UID = 10150
        const val TAP_REQUEST = "POST /commands/tap HTTP/1.1\r\nHost: 127.0.0.1:51234\r\n" +
            "Content-Type: application/json\r\nContent-Length: 2\r\n\r\n{}"
    }
}
