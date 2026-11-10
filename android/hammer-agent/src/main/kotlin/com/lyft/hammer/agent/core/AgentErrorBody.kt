package com.lyft.hammer.agent.core

import com.google.gson.JsonObject

/** The body of a failed response. Mirrors `AgentErrorBody` in Hammer's `HammerAgentCore`. */
data class AgentErrorBody(
    val error: String,
    val code: String? = null,
    val hint: String? = null,
) {
    fun toJson(): JsonObject = JsonObject().apply {
        addProperty("error", error)
        code?.let { addProperty("code", it) }
        hint?.let { addProperty("hint", it) }
    }
}

/** Stable error codes clients match on. Commands may add their own snake case codes. */
object AgentErrorCode {
    const val INVALID_ARGUMENTS = "invalid_arguments"
    const val UNKNOWN_COMMAND = "unknown_command"
    const val INVALID_REQUEST = "invalid_request"
    const val FAILED = "failed"
    const val NOT_FOUND = "not_found"
    const val AMBIGUOUS_TARGET = "ambiguous_target"
    const val NOT_VISIBLE = "not_visible"
    const val NOT_HITTABLE = "not_hittable"
    const val NOT_READY = "not_ready"
    const val TIMED_OUT = "timed_out"
}
