package com.lyft.hammer.agent

import android.app.Activity
import android.view.View
import com.lyft.hammer.agent.ui.AgentScreen
import com.lyft.hammer.agent.ui.Target

/**
 * The state of one command run, for commands that work with what the built-in ones see. Mirrors
 * `AgentContext` in Hammer.
 */
public class AgentContext internal constructor(private val screen: AgentScreen) {

    /** The activity in the foreground, or null while the app has none, such as while it launches. */
    public val foregroundActivity: Activity?
        get() = screen.activities.resumedActivity

    /**
     * Returns the ref clients use to target [view] in later commands, the same one `describe` reports.
     *
     * @param view the view.
     * @return the ref, such as `e12`.
     */
    public fun ref(view: View): String = screen.references.ref(view, nodeId = null)

    /**
     * Returns the view a ref from `describe` or [ref] points to.
     *
     * @param ref the ref.
     * @return the view.
     * @throws AgentError with the code `invalid_arguments` if the ref is unknown, its view was released,
     *   or it points to a Jetpack Compose semantics node rather than a view.
     */
    public fun view(ref: String): View {
        val (owner, nodeId) = screen.references.owner(ref)
            ?: throw Target.invalid("Unknown ref $ref", hint = "Refs change when elements go away, call describe for the current ones")
        if (nodeId != null || owner !is View) {
            throw Target.invalid("Ref $ref is a Jetpack Compose semantics node, not a view")
        }
        return owner
    }
}
