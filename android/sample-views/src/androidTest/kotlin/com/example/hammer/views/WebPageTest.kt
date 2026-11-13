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
class WebPageTest {

    private val agent = AgentClient("com.example.hammer.views")
    private lateinit var scenario: ActivityScenario<WebPageActivity>

    @Before
    fun launch() {
        scenario = ActivityScenario.launch(WebPageActivity::class.java)
        agent.runOk("wait_for", arguments("identifier" to "web_page", "timeout" to 10))
    }

    @After
    fun close() {
        scenario.close()
    }

    @Test
    fun describe_marksTheWebViewForASystemRead() {
        val web = agent.element { it.optString("identifier") == "web_page" }

        assertThat(web?.optBoolean("needsSystemRead")).isTrue()
        assertThat(web?.has("children")).isFalse()
    }
}
