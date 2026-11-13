package com.lyft.hammer.agent.ui

/**
 * A view or Compose semantics node on screen, read on the main thread and used from any thread.
 *
 * @property owner the View it is, or the Compose root that holds it; refs are kept per owner.
 * @property nodeId the semantics node id within [owner], or null for a View.
 * @property consumesTouches whether a touch at its location stops at it, such as a clickable view
 *   or a window's root, which decides what else is hittable.
 * @property needsSystemRead whether its content exists only for accessibility services, such as a web
 *   page's, which the hammer tool reads through its system helper.
 * @property accessibilityClass the class accessibility services read a [needsSystemRead] view as, such as
 *   `android.webkit.WebView` for a web view of any subclass, so the tool finds it in the helper's read.
 */
internal class Element(
    val owner: Any,
    val nodeId: Int?,
    val type: String,
    val identifier: String?,
    val label: String?,
    val value: String?,
    val traits: Set<String>,
    val frame: Frame,
    val visible: Boolean,
    val consumesTouches: Boolean,
    val children: List<Element>,
    val needsSystemRead: Boolean = false,
    val accessibilityClass: String? = null,
) {
    var ref: String = ""
    var hittable: Boolean = false

    val touchPoint: Point
        get() = frame.center

    val hasAccessibilityInfo: Boolean
        get() = !identifier.isNullOrEmpty() || !label.isNullOrEmpty() || !value.isNullOrEmpty() || traits.isNotEmpty()

    val isActionable: Boolean
        get() = consumesTouches || traits.any { it in ACTIONABLE_TRAITS }

    fun withChildren(children: List<Element>) =
        Element(owner, nodeId, type, identifier, label, value, traits, frame, visible, consumesTouches, children, needsSystemRead, accessibilityClass)
            .also { it.ref = ref }

    private companion object {
        val ACTIONABLE_TRAITS = setOf(Traits.BUTTON, Traits.LINK, Traits.ADJUSTABLE)
    }
}

/** Hammer's accessibility trait names, which Android elements map onto. */
internal object Traits {
    const val BUTTON = "button"
    const val LINK = "link"
    const val HEADER = "header"
    const val SEARCH_FIELD = "searchField"
    const val IMAGE = "image"
    const val SELECTED = "selected"
    const val STATIC_TEXT = "staticText"
    const val NOT_ENABLED = "notEnabled"
    const val ADJUSTABLE = "adjustable"
    const val TAB_BAR = "tabBar"
    const val TOGGLE_BUTTON = "toggleButton"

    /** Every name Hammer accepts, so queries for the ones Android never sets still validate. */
    val ALL = listOf(
        BUTTON, LINK, HEADER, SEARCH_FIELD, IMAGE, SELECTED, "playsSound", "keyboardKey", STATIC_TEXT,
        "summaryElement", NOT_ENABLED, "updatesFrequently", "startsMediaSession", ADJUSTABLE,
        "allowsDirectInteraction", "causesPageTurn", TAB_BAR, TOGGLE_BUTTON, "supportsZoom",
    )
}
