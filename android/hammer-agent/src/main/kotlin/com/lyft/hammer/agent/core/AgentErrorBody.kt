package com.lyft.hammer.agent.core

import com.google.gson.JsonObject

/** The body of a failed response. Mirrors `AgentErrorBody` in Hammer's `HammerAgentCore`. */
internal data class AgentErrorBody(
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
