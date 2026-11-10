package com.example.hammer.compose

import android.util.Base64
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.lyft.hammer.agent.testing.AgentClient
import com.lyft.hammer.agent.testing.arguments
import org.assertj.core.api.Assertions.assertThat
import org.json.JSONArray
import org.json.JSONObject
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class ComposeScreenTest {

    private val agent = AgentClient("com.example.hammer.compose")
    private lateinit var scenario: ActivityScenario<ComposeActivity>

    @Before
    fun launch() {
        scenario = ActivityScenario.launch(ComposeActivity::class.java)
        agent.runOk("wait_for", arguments("identifier" to "count_button", "timeout" to 10))
    }

    @After
    fun close() {
        scenario.close()
    }

    @Test
    fun describe_composeScreen_listsTheSemanticsNodes() {
        val button = agent.element { it.optString("identifier") == "count_button" }
        val heading = agent.element { it.optString("label") == "Compose" }

        assertThat(button?.getString("label")).isEqualTo("Count")
        assertThat(button?.getJSONArray("traits")?.toList()).containsExactly("button")
        assertThat(button?.getBoolean("hittable")).isTrue()
        assertThat(heading?.getJSONArray("traits")?.toList()).containsExactly("header")
    }

    @Test
    fun tapByIdentifierLabelAndRef_countsEachTap() {
        agent.runOk("tap", arguments("identifier" to "count_button"))
        agent.runOk("wait_for", arguments("label" to "Count: 1", "timeout" to 5))

        agent.runOk("tap", arguments("label" to "Count", "traits" to listOf("button")))
        agent.runOk("wait_for", arguments("label" to "Count: 2", "timeout" to 5))

        val ref = agent.element { it.optString("identifier") == "count_button" }!!.getString("ref")
        agent.runOk("tap", arguments("ref" to ref))
        agent.runOk("wait_for", arguments("label" to "Count: 3", "timeout" to 5))
    }

    @Test
    fun typeText_intoTheField_setsItsValue() {
        agent.runOk("type_text", arguments("identifier" to "message_field", "text" to "Hi there"))

        agent.runOk("wait_for", arguments("identifier" to "message_field", "value" to "Hi there", "timeout" to 5))
    }

    @Test
    fun swipeUp_scrollsTheFirstRowAway() {
        agent.runOk("wait_for", arguments("label" to "Row 1", "condition" to "visible", "timeout" to 5))

        // The swipe is centered on the list, so it has to fit inside it on small screens
        val listHeight = agent.element { it.optString("identifier") == "rows" }!!.getJSONObject("frame").getDouble("height")
        agent.runOk("swipe", arguments("identifier" to "rows", "direction" to "up", "distance" to listHeight * 0.8))

        agent.runOk("wait_for", arguments("label" to "Row 1", "condition" to "gone", "timeout" to 5))
    }

    @Test
    fun screenshot_oneElement_isAPng() {
        val image = JSONObject(agent.runOk("screenshot", arguments("identifier" to "count_button")))

        assertThat(image.getString("mimeType")).isEqualTo("image/png")
        assertThat(Base64.decode(image.getString("data"), Base64.DEFAULT).take(PNG_SIGNATURE.size))
            .containsExactlyElementsOf(PNG_SIGNATURE)
    }

    @Test
    fun pressKeyDeviceBack_closesTheScreen() {
        agent.runOk("press_key", arguments("key" to "deviceBack"))

        agent.runOk("wait_for", arguments("identifier" to "count_button", "condition" to "gone", "timeout" to 10))
    }

    private fun JSONArray.toList(): List<String> = (0 until length()).map { getString(it) }

    private companion object {
        val PNG_SIGNATURE = listOf<Byte>(-119, 80, 78, 71, 13, 10, 26, 10)
    }
}
