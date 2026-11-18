package com.lyft.hammer.agent

/**
 * An error a command reports to the client, with a code clients can match and a hint on how to fix it.
 * Mirrors `AgentError` in Hammer.
 *
 * @param message what went wrong.
 * @property code a stable snake case name, one of [AgentErrorCode] or the command's own, such as
 *   `unknown_flag`. `invalid_arguments` answers with HTTP status 400, any other code with 500.
 * @property hint how to fix it, such as the command to call first, or null.
 */
public class AgentError(
    message: String,
    public val code: String = AgentErrorCode.FAILED,
    public val hint: String? = null,
) : Exception(message)

/**
 * The stable error codes the agent reports. Mirrors the agent side of `AgentErrorCode` in Hammer;
 * commands can add their own snake case codes.
 */
public object AgentErrorCode {
    /** The arguments are missing, of the wrong type, or don't make sense together. */
    public const val INVALID_ARGUMENTS: String = "invalid_arguments"

    /** The app has no command with that name. */
    public const val UNKNOWN_COMMAND: String = "unknown_command"

    /** The request is not one the agent accepts, such as one from a browser or another app. */
    public const val INVALID_REQUEST: String = "invalid_request"

    /** The command could not do what was asked, for a reason no other code describes. */
    public const val FAILED: String = "failed"

    /** No element or view matches the target. */
    public const val NOT_FOUND: String = "not_found"

    /** Several elements match the target. */
    public const val AMBIGUOUS_TARGET: String = "ambiguous_target"

    /** The element or view is hidden, off screen or no longer on screen. */
    public const val NOT_VISIBLE: String = "not_visible"

    /** Something covers the element or view, or it ignores touches. */
    public const val NOT_HITTABLE: String = "not_hittable"

    /** The app is busy, still launching, or another window has the keyboard focus. */
    public const val NOT_READY: String = "not_ready"

    /** A wait ran out of time. */
    public const val TIMED_OUT: String = "timed_out"
}
