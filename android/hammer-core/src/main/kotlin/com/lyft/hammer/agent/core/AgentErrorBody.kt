package com.lyft.hammer.agent.core

import com.lyft.hammer.agent.JsonValue

/** The body of a failed response. Mirrors `AgentErrorBody` in Hammer's `HammerAgentCore`. */
internal data class AgentErrorBody(
    val error: String,
    val code: String? = null,
    val hint: String? = null,
) {
    fun toJson(): JsonValue.Object = jsonObject("error" to error.json, "code" to code?.json, "hint" to hint?.json)
}
