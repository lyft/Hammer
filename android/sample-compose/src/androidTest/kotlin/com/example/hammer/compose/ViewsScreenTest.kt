package com.example.hammer.compose

import android.util.Base64
import android.widget.ScrollView
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.lyft.hammer.agent.testing.AgentClient
import com.lyft.hammer.agent.testing.arguments
import org.assertj.core.api.Assertions.assertThat
import org.json.JSONObject
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class ViewsScreenTest {

    private val agent = AgentClient("com.example.hammer.compose")
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
    fun describe_viewsScreen_listsTheViewsWithIdentifiersLabelsAndTraits() {
        val button = agent.element { it.optString("identifier") == "greet_button" }
        val title = agent.element { it.optString("identifier") == "title" }

        assertThat(button?.getString("label")).isEqualTo("Greet")
        assertThat(button?.getJSONArray("traits")?.toList()).containsExactly("button")
        assertThat(button?.getBoolean("hittable")).isTrue()
        assertThat(title?.getJSONArray("traits")?.toList()).containsExactly("header", "staticText")
    }

    @Test
    fun typeTextThenTapByIdentifier_greetsTheName() {
        agent.runOk("type_text", arguments("identifier" to "name_field", "text" to "Ada"))
        agent.runOk("tap", arguments("identifier" to "greet_button"))

        agent.runOk("wait_for", arguments("label" to "Hello, Ada", "timeout" to 5))
    }

    @Test
    fun tapByRef_greetsTheName() {
        agent.runOk("type_text", arguments("identifier" to "name_field", "text" to "Lin"))
        val ref = agent.element { it.optString("identifier") == "greet_button" }!!.getString("ref")

        agent.runOk("tap", arguments("ref" to ref))

        agent.runOk("wait_for", arguments("label" to "Hello, Lin", "timeout" to 5))
    }

    @Test
    fun tapByLabelThenDeviceBack_opensAndClosesTheComposeScreen() {
        agent.runOk("tap", arguments("label" to "Open the Compose screen"))
        agent.runOk("wait_for", arguments("identifier" to "count_button", "timeout" to 10))

        agent.runOk("press_key", arguments("key" to "deviceBack"))

        agent.runOk("wait_for", arguments("identifier" to "count_button", "condition" to "gone", "timeout" to 10))
        agent.runOk("wait_for", arguments("identifier" to "greet_button", "condition" to "hittable", "timeout" to 10))
    }

    @Test
    fun swipeUp_scrollsTheList() {
        agent.runOk("swipe", arguments("identifier" to "items", "direction" to "up"))
        agent.runOk("wait_for_idle")

        var scrollY = 0
        scenario.onActivity { scrollY = it.findViewById<ScrollView>(R.id.items).scrollY }
        assertThat(scrollY).isGreaterThan(0)
    }

    @Test
    fun screenshot_wholeScreen_isAPng() {
        val image = JSONObject(agent.runOk("screenshot"))

        assertThat(image.getString("type")).isEqualTo("image")
        assertThat(image.getString("mimeType")).isEqualTo("image/png")
        assertThat(Base64.decode(image.getString("data"), Base64.DEFAULT).take(PNG_SIGNATURE.size))
            .containsExactlyElementsOf(PNG_SIGNATURE)
    }

    @Test
    fun customCommand_isListedAndRuns() {
        val names = agent.commands().let { commands -> (0 until commands.length()).map { commands.getJSONObject(it).getString("name") } }

        val output = JSONObject(agent.runOk("show_greeting", arguments("name" to "Ada")))

        assertThat(names).endsWith("show_greeting")
        agent.runOk("wait_for", arguments("label" to "Hello, Ada", "timeout" to 5))
        assertThat(agent.element { it.optString("ref") == output.getString("ref") }?.getString("label")).isEqualTo("Hello, Ada")
    }

    @Test
    fun customCommand_missingName_isInvalidArguments() {
        val response = agent.run("show_greeting")

        assertThat(response.status).isEqualTo(400)
        assertThat(response.json.getString("code")).isEqualTo("invalid_arguments")
    }

    private fun org.json.JSONArray.toList(): List<String> = (0 until length()).map { getString(it) }

    private companion object {
        val PNG_SIGNATURE = listOf<Byte>(-119, 80, 78, 71, 13, 10, 26, 10)
    }
}
