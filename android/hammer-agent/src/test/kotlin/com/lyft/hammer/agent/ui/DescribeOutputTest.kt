package com.lyft.hammer.agent.ui

import com.google.gson.JsonParser
import org.assertj.core.api.Assertions.assertThat
import org.junit.Test

class DescribeOutputTest {

    private val label = element("e4", Frame(16.04, 120.06, 343.0, 20.0), label = "Sign In", traits = setOf("staticText"))
    private val hidden = element("e5", Frame(0.0, 0.0, 10.0, 10.0), label = "Error", visible = false)
    private val button = element(
        "e3",
        Frame(16.0, 600.0, 343.0, 50.0),
        identifier = "sign_in",
        traits = setOf("selected", "button"),
        consumesTouches = true,
        children = listOf(label),
    )
    private val container = element("e2", SCREEN, children = listOf(button, hidden))
    private val snapshot = Snapshot(listOf(window(container)), SCREEN)

    @Test
    fun json_default_keepsOnlyAccessibleVisibleElements() {
        assertThat(DescribeOutput.json(snapshot, all = false)).isEqualTo(
            JsonParser.parseString(
                """
                [{"ref": "e3", "type": "android.view.View", "identifier": "sign_in", "traits": ["button", "selected"],
                  "frame": {"x": 16, "y": 600, "width": 343, "height": 50}, "hittable": true,
                  "children": [{"ref": "e4", "type": "android.view.View", "label": "Sign In", "traits": ["staticText"],
                                "frame": {"x": 16, "y": 120.1, "width": 343, "height": 20}, "hittable": true}]}]
                """,
            ),
        )
    }

    @Test
    fun json_all_keepsContainersButNotHiddenElements() {
        val refs = mutableListOf<String>()
        fun collect(nodes: com.google.gson.JsonArray) {
            nodes.forEach { node ->
                refs += node.asJsonObject["ref"].asString
                node.asJsonObject.getAsJsonArray("children")?.let(::collect)
            }
        }

        collect(DescribeOutput.json(snapshot, all = true))

        assertThat(refs).containsExactly("e1", "e2", "e3", "e4")
    }
}
