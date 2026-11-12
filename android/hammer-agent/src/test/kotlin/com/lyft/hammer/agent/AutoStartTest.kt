package com.lyft.hammer.agent

import org.assertj.core.api.Assertions.assertThat
import org.junit.Test

class AutoStartTest {

    private val log = RecordingLog()

    @Test
    fun run_debuggableApp_startsTheAgent() {
        val environment = FakeEnvironment()

        val agent = AutoStart.run(environment, log)

        assertThat(agent).isNotNull()
        assertThat(environment.listens).containsExactly("hammer_com.example.app")
    }

    @Test
    fun run_releaseBuild_onlyLogs() {
        val environment = FakeEnvironment(isDebuggable = false)

        val agent = AutoStart.run(environment, log)

        assertThat(agent).isNull()
        assertThat(environment.listens).isEmpty()
        assertThat(log.lines).containsExactly(
            "W Hammer agent didn't start; the app isn't debuggable, and auto-start runs only in debuggable builds",
        )
    }

    @Test
    fun run_turnedOffInTheManifest_doesNotStart() {
        val environment = FakeEnvironment(manifestEntries = mapOf("com.lyft.hammer.agent.autostart" to "false"))

        val agent = AutoStart.run(environment, log)

        assertThat(agent).isNull()
        assertThat(environment.listens).isEmpty()
        assertThat(log.lines).containsExactly("I Hammer agent auto-start is off in the app's manifest")
    }

    @Test
    fun run_socketTaken_logsTheErrorInsteadOfThrowing() {
        val environment = FakeEnvironment(socketTaken = true)

        val agent = AutoStart.run(environment, log)

        assertThat(agent).isNull()
        assertThat(log.lines).containsExactly(
            "E The Hammer agent can't listen on @hammer_com.example.app; another process may already own it",
        )
    }
}
