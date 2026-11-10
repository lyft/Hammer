package com.example.hammer.views

import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.lyft.hammer.agent.testing.AgentClient
import com.lyft.hammer.agent.testing.arguments
import org.assertj.core.api.Assertions.assertThat
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class ViewsOnlyTest {

    private val agent = AgentClient("com.example.hammer.views")
    private lateinit var scenario: ActivityScenario<MainActivity>

    @Before
    fun launch() {
        scenario = ActivityScenario.launch(MainActivity::class.java)
        agent.runOk("wait_for", arguments("identifier" to "greet_button", "timeout" to 10))
    }

    @After
    fun close() {
        scenario.close()
    }

    @Test
    fun composeUi_isNotOnTheClasspath() {
        assertThat(runCatching { Class.forName("androidx.compose.ui.node.RootForTest") }.exceptionOrNull())
            .isInstanceOf(ClassNotFoundException::class.java)
    }

    @Test
    fun describe_listsTheViews() {
        val button = agent.element { it.optString("identifier") == "greet_button" }

        assertThat(button?.getString("label")).isEqualTo("Greet")
        assertThat(button?.getBoolean("hittable")).isTrue()
    }

    @Test
    fun typeTextThenTap_greetsTheName() {
        agent.runOk("type_text", arguments("identifier" to "name_field", "text" to "Ada"))
        agent.runOk("tap", arguments("label" to "Greet"))

        agent.runOk("wait_for", arguments("label" to "Hello, Ada", "timeout" to 5))
    }
}
