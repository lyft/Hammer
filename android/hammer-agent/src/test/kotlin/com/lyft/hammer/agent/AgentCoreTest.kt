package com.lyft.hammer.agent

import com.lyft.hammer.agent.core.WireCommand
import com.lyft.hammer.agent.core.emptyJsonObject
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.Test
import java.io.IOException

class AgentCoreTest {

    private val log = RecordingLog()

    @Test
    fun start_debuggableApp_listensAndLogsWhoCanConnect() {
        val environment = FakeEnvironment()

        val listening = AgentCore(environment, log).start(allowsReleaseBuild = false)

        assertThat(listening).isTrue()
        assertThat(environment.listens).containsExactly("hammer_com.example.app")
        assertThat(log.lines).containsExactly("I Hammer agent listening on @hammer_com.example.app, adb and this app can control it")
    }

    @Test
    fun start_releaseBuild_throwsWithoutListening() {
        val environment = FakeEnvironment(isDebuggable = false)

        assertThatThrownBy { AgentCore(environment, log).start(allowsReleaseBuild = false) }
            .isInstanceOf(AgentStartError.ReleaseBuild::class.java)
            .hasMessageContaining("allowsReleaseBuild")
        assertThat(environment.listens).isEmpty()
    }

    @Test
    fun start_releaseBuildAllowed_listens() {
        val environment = FakeEnvironment(isDebuggable = false)

        AgentCore(environment, log).start(allowsReleaseBuild = true)

        assertThat(environment.listens).containsExactly("hammer_com.example.app")
    }

    @Test
    fun start_socketTaken_throwsSocketUnavailable() {
        val environment = FakeEnvironment(socketTaken = true)

        assertThatThrownBy { AgentCore(environment, log).start(allowsReleaseBuild = false) }
            .isInstanceOfSatisfying(AgentStartError.SocketUnavailable::class.java) {
                assertThat(it.socketName).isEqualTo("hammer_com.example.app")
                assertThat(it.message).isEqualTo("The Hammer agent can't listen on @hammer_com.example.app; another process may already own it")
                assertThat(it.cause).isInstanceOf(IOException::class.java)
            }
        assertThat(log.lines).isEmpty()
    }

    @Test
    fun start_socketHeldByAnotherAgentInThisProcess_pointsToAutoStart() {
        val process = ListeningSockets()
        AgentCore(FakeEnvironment(listeningSockets = process), log).start(allowsReleaseBuild = false)

        assertThatThrownBy { AgentCore(FakeEnvironment(socketTaken = true, listeningSockets = process), log).start(allowsReleaseBuild = false) }
            .isInstanceOfSatisfying(AgentStartError.SocketUnavailable::class.java) {
                assertThat(it.message).isEqualTo(
                    "The Hammer agent can't listen on @hammer_com.example.app; another agent in this process already does, " +
                        "such as the one auto-start runs. To start your own, turn auto-start off with the " +
                        "com.lyft.hammer.agent.autostart meta-data",
                )
                assertThat(it.cause).isInstanceOf(IOException::class.java)
            }
    }

    @Test
    fun start_socketTakenAfterThisProcessStoppedItsAgent_blamesAnotherProcess() {
        val process = ListeningSockets()
        val first = AgentCore(FakeEnvironment(listeningSockets = process), log)
        first.start(allowsReleaseBuild = false)
        first.stop()

        assertThatThrownBy { AgentCore(FakeEnvironment(socketTaken = true, listeningSockets = process), log).start(allowsReleaseBuild = false) }
            .hasMessage("The Hammer agent can't listen on @hammer_com.example.app; another process may already own it")
    }

    @Test
    fun start_otherProcess_logsAndDoesNotListen() {
        val environment = FakeEnvironment(otherProcessName = "com.example.app:remote")

        val listening = AgentCore(environment, log).start(allowsReleaseBuild = false)

        assertThat(listening).isFalse()
        assertThat(environment.listens).isEmpty()
        assertThat(log.lines).containsExactly(
            "W Hammer agent didn't start in process com.example.app:remote; it runs only in the app's main process",
        )
    }

    @Test
    fun start_twice_listensOnce() {
        val environment = FakeEnvironment()
        val core = AgentCore(environment, log)

        core.start(allowsReleaseBuild = false)
        core.start(allowsReleaseBuild = false)

        assertThat(environment.listens).hasSize(1)
    }

    @Test
    fun stop_afterStart_closesAndAllowsStartingAgain() {
        val environment = FakeEnvironment()
        val core = AgentCore(environment, log)
        core.start(allowsReleaseBuild = false)

        core.stop()
        core.start(allowsReleaseBuild = false)

        assertThat(environment.closes).isEqualTo(1)
        assertThat(environment.listens).hasSize(2)
    }

    @Test
    fun register_afterStart_isListedAfterTheBuiltins() {
        val core = AgentCore(FakeEnvironment(builtins = listOf(builtin("tap"))), log)
        core.start(allowsReleaseBuild = false)

        core.register(appCommand("sign_in"))

        assertThat(core.commands.map { it.name }).containsExactly("tap", "sign_in")
    }

    @Test
    fun register_reservedParameterName_throws() {
        val core = AgentCore(FakeEnvironment(), log)
        val command = appCommand("save", CommandDescriptor.Parameter("serial", CommandDescriptor.ParameterType.StringValue, ""))

        assertThatThrownBy { core.register(command) }
            .isInstanceOf(IllegalArgumentException::class.java)
            .hasMessage("Command save uses reserved parameter names: [serial]")
    }

    private fun builtin(name: String): WireCommand = object : WireCommand {
        override val descriptor = CommandDescriptor(name, "")

        override suspend fun run(arguments: JsonValue.Object): JsonValue = emptyJsonObject
    }

    private fun appCommand(name: String, vararg parameters: CommandDescriptor.Parameter): AgentCommand = object : AgentCommand {
        override val descriptor = CommandDescriptor(name, "", parameters.toList())

        override suspend fun run(arguments: JsonValue.Object, context: AgentContext): JsonValue = JsonValue.Object()
    }
}
