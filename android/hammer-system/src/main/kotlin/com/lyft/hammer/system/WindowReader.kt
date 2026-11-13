package com.lyft.hammer.system

import android.app.UiAutomation
import android.graphics.Rect
import android.os.Build
import android.view.accessibility.AccessibilityNodeInfo
import android.view.accessibility.AccessibilityWindowInfo
import com.lyft.hammer.agent.JsonValue
import com.lyft.hammer.agent.core.json
import com.lyft.hammer.agent.core.jsonObject

/** A window on screen and its accessibility nodes, read from UiAutomation. */
internal data class WindowData(
    val layer: Int,
    val type: String,
    val title: String?,
    val bounds: Bounds,
    val focused: Boolean,
    val root: NodeData,
)

/**
 * An accessibility node, with uiautomator's attribute names, so the tool reads the helper's nodes as it
 * reads `uiautomator dump`. Only visible nodes are kept, as uiautomator does.
 */
internal data class NodeData(
    val className: String?,
    val packageName: String?,
    val text: String?,
    val contentDescription: String?,
    val resourceId: String?,
    val hint: String?,
    val bounds: Bounds,
    val flags: Set<String>,
    val children: List<NodeData>,
)

/** A rectangle in pixels, which unit tests can make, unlike [Rect]. */
internal data class Bounds(val left: Int, val top: Int, val right: Int, val bottom: Int)

private val Rect.bounds: Bounds
    get() = Bounds(left, top, right, bottom)

/** Reads every window on screen from UiAutomation, back to front. */
internal class WindowReader(private val automation: UiAutomation) {

    fun windows(): List<WindowData> = automation.windows
        .sortedBy { it.layer }
        .mapNotNull { window ->
            val root = window.root ?: return@mapNotNull null
            WindowData(
                layer = window.layer,
                type = typeName(window.type),
                title = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) window.title?.toString() else null,
                bounds = Rect().also(window::getBoundsInScreen).bounds,
                focused = window.isFocused,
                root = node(root, depth = 0) ?: return@mapNotNull null,
            )
        }

    private fun node(info: AccessibilityNodeInfo, depth: Int): NodeData? {
        if (!info.isVisibleToUser || depth > MAX_DEPTH) return null
        val children = (0 until info.childCount).mapNotNull { index -> info.getChild(index)?.let { node(it, depth + 1) } }
        val actions = info.actionList.map { it.id }.toSet()
        val showingHint = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && info.isShowingHintText
        return NodeData(
            className = info.className?.toString(),
            packageName = info.packageName?.toString(),
            text = if (showingHint) null else info.text?.toString(),
            contentDescription = info.contentDescription?.toString(),
            resourceId = info.viewIdResourceName,
            hint = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) info.hintText?.toString() else null,
            bounds = Rect().also(info::getBoundsInScreen).bounds,
            flags = buildSet {
                if (info.isClickable) add("clickable")
                if (info.isLongClickable) add("long-clickable")
                if (info.isCheckable) add("checkable")
                if (info.isChecked) add("checked")
                if (info.isSelected) add("selected")
                if (!info.isEnabled) add("disabled")
                if (info.isFocused) add("focused")
                if (info.isEditable) add("editable")
                if (info.isPassword) add("password")
                if (info.isScrollable) add("scrollable")
                if (AccessibilityNodeInfo.ACTION_SCROLL_FORWARD in actions) add("scroll-forward")
                if (AccessibilityNodeInfo.ACTION_SCROLL_BACKWARD in actions) add("scroll-backward")
            },
            children = children,
        )
    }

    private fun typeName(type: Int): String = when (type) {
        AccessibilityWindowInfo.TYPE_APPLICATION -> "application"
        AccessibilityWindowInfo.TYPE_INPUT_METHOD -> "inputMethod"
        AccessibilityWindowInfo.TYPE_SYSTEM -> "system"
        AccessibilityWindowInfo.TYPE_ACCESSIBILITY_OVERLAY -> "accessibilityOverlay"
        AccessibilityWindowInfo.TYPE_SPLIT_SCREEN_DIVIDER -> "splitScreenDivider"
        else -> "other"
    }

    private companion object {
        // Deeper trees are layout noise, and the cap keeps a pathological one from overflowing the stack
        const val MAX_DEPTH = 128
    }
}

/** The JSON the tool decodes, in pixels. */
internal object WindowJson {

    fun encode(windows: List<WindowData>, packageName: String?): JsonValue.Object = jsonObject(
        "windows" to JsonValue.Array(
            windows.filter { packageName == null || it.root.packageName == packageName }.map { window ->
                jsonObject(
                    "layer" to window.layer.json,
                    "type" to window.type.json,
                    "title" to window.title?.json,
                    "package" to window.root.packageName?.json,
                    "bounds" to window.bounds.json(),
                    "focused" to window.focused.json,
                    "root" to node(window.root),
                )
            },
        ),
    )

    private fun node(node: NodeData): JsonValue.Object = jsonObject(
        "class" to node.className?.json,
        "package" to node.packageName?.json,
        "text" to node.text?.takeIf { it.isNotEmpty() }?.json,
        "content-desc" to node.contentDescription?.takeIf { it.isNotEmpty() }?.json,
        "resource-id" to node.resourceId?.takeIf { it.isNotEmpty() }?.json,
        "hint" to node.hint?.takeIf { it.isNotEmpty() }?.json,
        "bounds" to node.bounds.json(),
        "flags" to node.flags.takeIf { it.isNotEmpty() }?.let { flags -> JsonValue.Array(flags.sorted().map { it.json }) },
        "children" to node.children.takeIf { it.isNotEmpty() }?.let { children -> JsonValue.Array(children.map(::node)) },
    )

    private fun Bounds.json() = JsonValue.Array(left.json, top.json, right.json, bottom.json)
}
