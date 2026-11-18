package com.lyft.hammer.system

import com.lyft.hammer.agent.core.Json
import org.assertj.core.api.Assertions.assertThat
import org.junit.Test

class WindowJsonTest {

    private fun node(
        className: String,
        text: String? = null,
        flags: Set<String> = emptySet(),
        children: List<NodeData> = emptyList(),
        packageName: String = APP,
    ) = NodeData(className, packageName, text, null, null, null, Bounds(0, 0, 100, 50), flags, children)

    private fun window(layer: Int, root: NodeData, type: String = "application") =
        WindowData(layer, type, null, Bounds(0, 0, 1080, 2400), focused = false, root = root)

    @Test
    fun encode_nodes_useUiautomatorsAttributeNamesAndLeaveOutEmptyOnes() {
        val field = node("android.widget.EditText", text = "", flags = setOf("password", "focused", "editable"))
        val list = node("androidx.recyclerview.widget.RecyclerView", flags = setOf("scroll-forward", "scrollable"), children = listOf(field))

        val json = Json.encode(WindowJson.encode(listOf(window(1, list)), packageName = null))

        assertThat(json).isEqualTo(
            """{"windows":[{"layer":1,"type":"application","package":"$APP","bounds":[0,0,1080,2400],"focused":false,""" +
                """"root":{"class":"androidx.recyclerview.widget.RecyclerView","package":"$APP","bounds":[0,0,100,50],""" +
                """"flags":["scroll-forward","scrollable"],"children":[{"class":"android.widget.EditText","package":"$APP",""" +
                """"bounds":[0,0,100,50],"flags":["editable","focused","password"]}]}}]}""",
        )
    }

    @Test
    fun encode_package_keepsOnlyThatAppsWindows() {
        val windows = listOf(window(1, node("android.widget.FrameLayout")), window(2, node("android.widget.FrameLayout", packageName = SYSTEM_UI), type = "system"))

        val json = Json.encode(WindowJson.encode(windows, packageName = SYSTEM_UI))

        assertThat(json).contains(""""package":"$SYSTEM_UI"""").doesNotContain(""""package":"$APP"""")
    }

    private companion object {
        const val APP = "com.example.app"
        const val SYSTEM_UI = "com.android.systemui"
    }
}
