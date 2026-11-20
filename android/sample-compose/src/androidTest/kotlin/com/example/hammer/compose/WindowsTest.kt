package com.example.hammer.compose

import android.app.Dialog
import android.widget.Button
import android.widget.EditText
import android.widget.TextView
import androidx.activity.ComponentDialog
import androidx.activity.OnBackPressedCallback
import androidx.test.core.app.ActivityScenario
import androidx.test.espresso.IdlingRegistry
import androidx.test.espresso.IdlingResource
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.lyft.hammer.agent.testing.AgentClient
import com.lyft.hammer.agent.testing.arguments
import org.assertj.core.api.Assertions.assertThat
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.util.concurrent.atomic.AtomicInteger

@RunWith(AndroidJUnit4::class)
class WindowsTest {

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
    fun describe_dialog_listsItsControls() {
        show { Dialog(it).apply { setContentView(Button(it).apply { text = "Inside" }) } }

        agent.runOk("wait_for", arguments("label" to "Inside", "condition" to "hittable", "timeout" to 5))
    }

    @Test
    fun tapOutsideASmallDialog_cancelsItInsteadOfTappingBehind() {
        show { Dialog(it).apply { setContentView(Button(it).apply { text = "Inside" }); setCanceledOnTouchOutside(true) } }
        agent.runOk("wait_for", arguments("label" to "Inside", "timeout" to 5))
        val greet = agent.element { it.optString("identifier") == "greet_button" }!!
        val frame = greet.getJSONObject("frame")

        agent.runOk("tap", arguments("x" to frame.getDouble("x") + frame.getDouble("width") / 2, "y" to frame.getDouble("y") + frame.getDouble("height") / 2))

        assertThat(greet.getBoolean("hittable")).isFalse()
        agent.runOk("wait_for", arguments("label" to "Inside", "condition" to "gone", "timeout" to 5))
        assertThat(greeting()).isEmpty()
    }

    @Test
    fun deviceBack_plainDialog_cancelsIt() {
        show { Dialog(it).apply { setContentView(Button(it).apply { text = "Inside" }) } }
        agent.runOk("wait_for", arguments("label" to "Inside", "timeout" to 5))

        agent.runOk("press_key", arguments("key" to "deviceBack"))

        agent.runOk("wait_for", arguments("label" to "Inside", "condition" to "gone", "timeout" to 5))
    }

    @Test
    fun deviceBack_componentDialog_runsItsBackCallback() {
        val backs = AtomicInteger()
        show { activity ->
            ComponentDialog(activity).apply {
                setContentView(Button(activity).apply { text = "Inside" })
                onBackPressedDispatcher.addCallback(object : OnBackPressedCallback(true) {
                    override fun handleOnBackPressed() {
                        backs.incrementAndGet()
                    }
                })
            }
        }
        agent.runOk("wait_for", arguments("label" to "Inside", "timeout" to 5))

        agent.runOk("press_key", arguments("key" to "deviceBack"))

        assertThat(backs.get()).isEqualTo(1)
    }

    @Test
    fun typeText_anyCharacters_typesThem() {
        agent.runOk("type_text", arguments("identifier" to "name_field", "text" to "Zoë 😀 你好"))

        var typed = ""
        scenario.onActivity { typed = it.findViewById<EditText>(R.id.name_field).text.toString() }
        assertThat(typed).isEqualTo("Zoë 😀 你好")
    }

    @Test
    fun typeText_noTextFieldFocused_isNotFound() {
        show { Dialog(it).apply { setContentView(Button(it).apply { text = "Inside" }) } }
        agent.runOk("wait_for", arguments("label" to "Inside", "timeout" to 5))

        val response = agent.run("type_text", arguments("text" to "lost"))

        assertThat(response.status).isEqualTo(500)
        assertThat(response.json.getString("code")).isEqualTo("not_found")
    }

    @Test
    fun waitForIdle_busyIdlingResource_waitsForIt() {
        val resource = BusyFor(BUSY_MILLIS)
        IdlingRegistry.getInstance().register(resource)
        try {
            val started = System.nanoTime()

            agent.runOk("wait_for_idle", arguments("timeout" to 10))

            assertThat((System.nanoTime() - started) / 1_000_000).isGreaterThanOrEqualTo(BUSY_MILLIS)
        } finally {
            IdlingRegistry.getInstance().unregister(resource)
        }
    }

    private fun show(dialog: (MainActivity) -> Dialog) {
        scenario.onActivity { dialog(it).show() }
    }

    private fun greeting(): String {
        var text = ""
        scenario.onActivity { text = it.findViewById<TextView>(R.id.greeting).text.toString() }
        return text
    }

    private class BusyFor(millis: Long) : IdlingResource {
        private val until = System.nanoTime() + millis * 1_000_000

        override fun getName() = "busy for a while"

        override fun isIdleNow() = System.nanoTime() >= until

        override fun registerIdleTransitionCallback(callback: IdlingResource.ResourceCallback?) = Unit
    }

    private companion object {
        const val BUSY_MILLIS = 1_500L
    }
}
