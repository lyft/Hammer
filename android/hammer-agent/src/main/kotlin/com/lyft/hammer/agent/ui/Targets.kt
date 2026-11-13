package com.lyft.hammer.agent.ui

import com.lyft.hammer.agent.AgentError
import com.lyft.hammer.agent.AgentErrorCode
import com.lyft.hammer.agent.JsonValue
import com.lyft.hammer.agent.core.closestMatch

/** What a command acts on, parsed from its target arguments as Hammer's `Target` does. */
internal sealed interface Target {
    data object None : Target
    data class Ref(val ref: String) : Target
    data class Query(val identifier: String?, val label: String?, val value: String?, val traits: List<String>) : Target {
        override fun toString(): String = listOfNotNull(
            identifier?.let { "identifier \"$it\"" },
            label?.let { "label \"$it\"" },
            value?.let { "value \"$it\"" },
            traits.takeIf { it.isNotEmpty() }?.let { "traits ${it.joinToString(", ")}" },
        ).joinToString(", ")
    }
    data class At(val point: Point) : Target

    companion object {
        /** Reads the target from [arguments], whose names may be prefixed, such as `to_ref`. */
        fun parse(arguments: JsonValue.Object, prefix: String = ""): Target {
            fun string(name: String) = arguments[prefix + name]?.stringValue
            val ref = string("ref")
            val traits = arguments[prefix + "traits"]?.arrayValue?.mapNotNull { it.stringValue }.orEmpty()
            val query = Query(string("identifier"), string("label"), string("value"), traits)
                .takeIf { it.identifier != null || it.label != null || it.value != null || traits.isNotEmpty() }
            val x = arguments[prefix + "x"]?.numberValue
            val y = arguments[prefix + "y"]?.numberValue
            if ((x == null) != (y == null)) {
                throw invalid("Pass both ${prefix}x and ${prefix}y for a point")
            }
            val point = if (x != null && y != null) At(Point(x, y)) else null
            val kinds = listOfNotNull(ref?.let(::Ref), query, point)
            if (kinds.size > 1) {
                throw invalid("Pass only one of a ref, a query (identifier, label, value, traits) or a point")
            }
            query?.traits?.forEach(::validateTrait)
            return kinds.firstOrNull() ?: None
        }

        private fun validateTrait(trait: String) {
            if (trait in Traits.ALL) return
            val suggestion = closestMatch(trait, Traits.ALL)?.let { ", did you mean $it?" }.orEmpty()
            throw invalid("Unknown trait \"$trait\"$suggestion", hint = "The traits are ${Traits.ALL.joinToString(", ")}")
        }

        fun invalid(message: String, hint: String? = null) = AgentError(message, AgentErrorCode.INVALID_ARGUMENTS, hint)
    }
}

/** Finds elements for targets, with Hammer's matching rules and errors. */
internal object TargetResolver {

    /** The element a ref or query picks. */
    fun element(target: Target, snapshot: Snapshot): Element = when (target) {
        is Target.Ref -> snapshot.element(target.ref) ?: throw Target.invalid(
            "Unknown ref ${target.ref}",
            hint = "Refs change when elements go away, call describe for the current ones",
        )
        is Target.Query -> match(target, snapshot)
        Target.None, is Target.At -> throw Target.invalid("Pass a ref or a query for the element")
    }

    /** Every element a query matches, before narrowing down to one. */
    fun matches(query: Target.Query, snapshot: Snapshot): List<Element> = snapshot.elements.filter { element ->
        (query.identifier == null || element.identifier == query.identifier) &&
            (query.label == null || element.label == query.label) &&
            (query.value == null || element.value == query.value) &&
            element.traits.containsAll(query.traits)
    }

    /** The point to touch for a target: an element's touch location, a point, or the window's center. */
    fun touchPoint(target: Target, snapshot: Snapshot): Point = when (target) {
        Target.None -> snapshot.windowFrame.center
        is Target.At -> target.point
        is Target.Ref, is Target.Query -> {
            val element = element(target, snapshot)
            if (!element.visible) {
                throw AgentError("Element ${element.ref} is not visible", AgentErrorCode.NOT_VISIBLE, NOT_VISIBLE_HINT)
            }
            if (!element.hittable) {
                val cover = snapshot.receiver(element.touchPoint)?.let { ", ${it.ref} (${it.type}) takes touches at its location" }
                throw AgentError("Element ${element.ref} is not hittable${cover.orEmpty()}", AgentErrorCode.NOT_HITTABLE, NOT_HITTABLE_HINT)
            }
            element.touchPoint
        }
    }

    private fun match(query: Target.Query, snapshot: Snapshot): Element =
        find(query, snapshot) ?: throw AgentError("Unable to find element: $query", AgentErrorCode.NOT_FOUND, NOT_FOUND_HINT)

    /** The one element a query picks, or null when none matches. */
    fun find(query: Target.Query, snapshot: Snapshot): Element? {
        val matches = matches(query, snapshot)
        if (matches.isEmpty()) return null
        val distinct = matches.fold(mutableListOf<Element>()) { kept, element ->
            val same = kept.indexOfFirst { it.touchPoint.isNear(element.touchPoint) }
            when {
                same < 0 -> kept += element
                element.isActionable && !kept[same].isActionable -> kept[same] = element
            }
            kept
        }
        val visible = distinct.filter { it.visible }.ifEmpty { distinct }
        val preferred = visible.filter { it.isActionable }.ifEmpty { visible }
        return preferred.singleOrNull() ?: throw AgentError(
            "Found ${preferred.size} elements for $query",
            AgentErrorCode.AMBIGUOUS_TARGET,
            "Add more of identifier, label, value and traits to tell them apart, or pass a ref from describe",
        )
    }

    private const val NOT_FOUND_HINT =
        "Call describe to see the elements on screen, or wait_for the element if it is still appearing"
    private const val NOT_VISIBLE_HINT =
        "It is hidden or off screen: swipe to scroll it into view, or wait_for it to be visible"
    private const val NOT_HITTABLE_HINT =
        "Something covers it or it ignores touches. Take a screenshot or call describe to see what is on top, " +
            "such as a dialog, a sheet or the keyboard"
}
