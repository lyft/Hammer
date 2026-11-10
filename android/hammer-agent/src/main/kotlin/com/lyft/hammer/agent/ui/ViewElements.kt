package com.lyft.hammer.agent.ui

import android.graphics.Rect
import android.view.View
import android.view.ViewGroup
import android.widget.Checkable
import android.widget.EditText
import android.widget.ImageView
import android.widget.TextView
import androidx.compose.ui.node.RootForTest

/** Reads Views into elements, and hands Compose roots to [ComposeElements]. */
internal class ViewElements(private val density: Double) {

    private val compose = ComposeElements(density)

    fun window(root: View, bounds: Rect): Element = element(root, bounds, opacity = 1f, isWindowRoot = true)

    private fun element(view: View, clip: Rect, opacity: Float, isWindowRoot: Boolean = false): Element {
        val bounds = ScreenReader.screenBounds(view)
        val visibleBounds = Rect(bounds)
        val onScreen = visibleBounds.intersect(clip) && !visibleBounds.isEmpty
        val alpha = opacity * view.alpha
        val visible = view.isShown && alpha >= MIN_ALPHA && onScreen
        val childClip = when {
            view is ViewGroup && !view.clipChildren -> clip
            onScreen -> visibleBounds
            else -> Rect()
        }
        val views = (view as? ViewGroup)?.let { group -> (0 until group.childCount).map { element(group.getChildAt(it), childClip, alpha) } }.orEmpty()
        val children = if (view is RootForTest) {
            // A Compose root's only View child is the handler of its interop Views
            InteropPlacement.place(compose.children(view, childClip, visible), views.flatMap { it.children })
        } else {
            views
        }
        return Element(
            owner = view,
            nodeId = null,
            type = view.javaClass.name,
            identifier = identifier(view),
            label = view.contentDescription?.toString() ?: (view as? TextView)?.takeUnless { it is EditText }?.text?.toString(),
            value = value(view),
            traits = traits(view),
            frame = (if (visible) visibleBounds else bounds).toFrame(density),
            visible = visible,
            consumesTouches = isWindowRoot || consumesTouches(view),
            children = children,
        )
    }

    private fun identifier(view: View): String? {
        // Generated ids have no package byte and no resource name
        if (view.id == View.NO_ID || view.id ushr PACKAGE_SHIFT == 0) return null
        return runCatching { view.resources.getResourceEntryName(view.id) }.getOrNull()
    }

    private fun value(view: View): String? = when (view) {
        is EditText -> view.text?.toString()
        is Checkable -> if (view.isChecked) "1" else "0"
        else -> null
    }

    private fun traits(view: View): Set<String> = buildSet {
        when {
            view is Checkable -> add(Traits.TOGGLE_BUTTON)
            view.isClickable -> add(Traits.BUTTON)
            view is ImageView && view.contentDescription != null -> add(Traits.IMAGE)
            view is TextView && view !is EditText && !view.text.isNullOrEmpty() -> add(Traits.STATIC_TEXT)
        }
        if (view.isSelected || (view as? Checkable)?.isChecked == true) add(Traits.SELECTED)
        if (!view.isEnabled) add(Traits.NOT_ENABLED)
        if (view.isAccessibilityHeading) add(Traits.HEADER)
    }

    private fun consumesTouches(view: View): Boolean {
        // Compose hit tests first and only hands a touch to an interop holder's view when that view takes it
        if (view.javaClass.name.startsWith(COMPOSE_INTEROP_PACKAGE)) return false
        return view.isClickable || view.isLongClickable || view is EditText ||
            view.canScrollVertically(1) || view.canScrollVertically(-1) ||
            view.canScrollHorizontally(1) || view.canScrollHorizontally(-1)
    }

    private companion object {
        const val MIN_ALPHA = 0.01f
        const val PACKAGE_SHIFT = 24
        const val COMPOSE_INTEROP_PACKAGE = "androidx.compose.ui.viewinterop."
    }
}

internal fun Rect.toFrame(density: Double) =
    Frame(left / density, top / density, width() / density, height() / density)
