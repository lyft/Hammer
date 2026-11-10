package com.lyft.hammer.agent.ui

import com.lyft.hammer.agent.core.AgentError
import com.lyft.hammer.agent.core.AgentErrorCode

/** What `wait_for` waits for, with Hammer's rules for each. */
internal enum class WaitCondition(val argument: String, private val expectedState: String) {
    EXISTS("exists", "found"),
    VISIBLE("visible", "visible"),
    HITTABLE("hittable", "hittable"),
    GONE("gone", "gone"),
    ;

    /**
     * Whether the element [query] picks is in this state, throwing if the query matches several. A null [snapshot]
     * means the app has no window in the foreground, where every element is gone.
     */
    fun isMet(query: Target.Query, snapshot: Snapshot?): Boolean = if (snapshot == null) this == GONE else when (this) {
        EXISTS -> TargetResolver.matches(query, snapshot).isNotEmpty()
        GONE -> TargetResolver.matches(query, snapshot).isEmpty()
        VISIBLE -> TargetResolver.find(query, snapshot)?.visible ?: false
        HITTABLE -> TargetResolver.find(query, snapshot)?.hittable ?: false
    }

    fun timedOut(query: Target.Query, timeoutSeconds: Double, exists: Boolean) = AgentError(
        "The element with $query was not $expectedState after $timeoutSeconds seconds, and it " +
            if (exists) "exists" else "does not exist",
        AgentErrorCode.TIMED_OUT,
        "Take a screenshot or call describe to see the current state, then wait for a different element or pass a longer timeout",
    )

    companion object {
        fun parse(argument: String?): WaitCondition =
            if (argument == null) HITTABLE else entries.first { it.argument == argument }

        /** The query to wait for. Refs and points don't work, since the element may not exist yet. */
        fun query(target: Target): Target.Query = target as? Target.Query ?: throw Target.invalid(
            "This command needs an element to look for",
            hint = "Pass any of identifier, label, value and traits. Refs and points are not supported here " +
                "since the element may not exist yet",
        )
    }
}
