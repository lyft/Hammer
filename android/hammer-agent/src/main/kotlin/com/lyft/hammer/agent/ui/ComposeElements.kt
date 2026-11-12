package com.lyft.hammer.agent.ui

import android.graphics.Rect
import android.view.View
import androidx.compose.ui.node.RootForTest
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.semantics.SemanticsConfiguration
import androidx.compose.ui.semantics.SemanticsNode
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.semantics.getOrNull
import androidx.compose.ui.state.ToggleableState
import kotlin.math.roundToInt

/**
 * Reads a Compose root's merged semantics tree into elements, the tree accessibility services and
 * Compose UI tests see. `testTag` is the identifier.
 *
 * The only class that names Compose types: Compose UI is a compile-only dependency, so create it only
 * when [OptionalLibraries.hasCompose].
 */
internal class ComposeElements(private val density: Double) {

    /** If [view] is the root of a composition, whose children are its semantics nodes. */
    fun isRoot(view: View): Boolean = view is RootForTest

    fun children(root: View, clip: Rect, rootVisible: Boolean): List<Element> {
        // Semantics bounds are in the window, so they are offset by where the window is on screen
        val windowOrigin = IntArray(2).also(root.rootView::getLocationOnScreen)
        return (root as RootForTest).semanticsOwner.rootSemanticsNode.children
            .map { element(it, root, windowOrigin, clip, rootVisible) }
    }

    private fun element(node: SemanticsNode, root: View, windowOrigin: IntArray, clip: Rect, parentVisible: Boolean): Element {
        val bounds = node.boundsInWindow.let {
            Rect(
                it.left.roundToInt() + windowOrigin[0],
                it.top.roundToInt() + windowOrigin[1],
                it.right.roundToInt() + windowOrigin[0],
                it.bottom.roundToInt() + windowOrigin[1],
            )
        }
        val visibleBounds = Rect(bounds)
        val visible = parentVisible && node.layoutInfo.isPlaced && visibleBounds.intersect(clip) && !visibleBounds.isEmpty
        val config = node.config
        val editable = config.getOrNull(SemanticsProperties.EditableText)
        return Element(
            owner = root,
            nodeId = node.id,
            type = type(config, editable != null),
            identifier = config.getOrNull(SemanticsProperties.TestTag),
            label = config.getOrNull(SemanticsProperties.ContentDescription)?.joinToString(", ")
                ?: config.getOrNull(SemanticsProperties.Text)?.joinToString(" ") { it.text },
            value = editable?.text ?: config.getOrNull(SemanticsProperties.StateDescription) ?: toggleValue(config),
            traits = traits(config, editable != null),
            frame = (if (visible) visibleBounds else bounds).toFrame(density),
            visible = visible,
            consumesTouches = consumesTouches(config),
            children = node.children.map { element(it, root, windowOrigin, if (visible) visibleBounds else Rect(), visible) },
        )
    }

    private fun type(config: SemanticsConfiguration, editable: Boolean): String {
        val role = config.getOrNull(SemanticsProperties.Role)
        val kind = when {
            role != null -> role.toString()
            editable -> "TextField"
            config.contains(SemanticsActions.OnClick) -> "Clickable"
            config.contains(SemanticsProperties.Text) -> "Text"
            else -> "Node"
        }
        return "Compose.$kind"
    }

    private fun toggleValue(config: SemanticsConfiguration): String? = when (config.getOrNull(SemanticsProperties.ToggleableState)) {
        ToggleableState.On -> "1"
        ToggleableState.Off -> "0"
        else -> null
    }

    private fun traits(config: SemanticsConfiguration, editable: Boolean): Set<String> = buildSet {
        roleTrait(config.getOrNull(SemanticsProperties.Role))?.let(::add)
        if (isEmpty() && config.contains(SemanticsActions.OnClick) && !editable) add(Traits.BUTTON)
        if (config.contains(SemanticsProperties.Heading)) add(Traits.HEADER)
        if (config.getOrNull(SemanticsProperties.Selected) == true ||
            config.getOrNull(SemanticsProperties.ToggleableState) == ToggleableState.On
        ) {
            add(Traits.SELECTED)
        }
        if (config.contains(SemanticsProperties.Disabled)) add(Traits.NOT_ENABLED)
        if (config.contains(SemanticsProperties.ProgressBarRangeInfo) && config.contains(SemanticsActions.SetProgress)) {
            add(Traits.ADJUSTABLE)
        }
        if (isEmpty() && !editable && config.contains(SemanticsProperties.Text)) add(Traits.STATIC_TEXT)
    }

    private fun roleTrait(role: Role?): String? = when (role) {
        Role.Button, Role.DropdownList, Role.Tab -> Traits.BUTTON
        Role.Checkbox, Role.Switch, Role.RadioButton -> Traits.TOGGLE_BUTTON
        Role.Image -> Traits.IMAGE
        else -> null
    }

    private fun consumesTouches(config: SemanticsConfiguration): Boolean =
        config.contains(SemanticsActions.OnClick) || config.contains(SemanticsActions.OnLongClick) ||
            config.contains(SemanticsActions.SetText) || config.contains(SemanticsActions.ScrollBy)
}
