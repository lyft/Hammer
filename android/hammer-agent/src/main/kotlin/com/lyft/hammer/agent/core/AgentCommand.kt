package com.lyft.hammer.agent.core

import com.google.gson.JsonElement
import com.google.gson.JsonObject

/**
 * A command the agent runs for its clients, built in like `tap` or added by the app. Mirrors
 * `AgentCommand` in Hammer. The agent validates arguments against [descriptor] before calling [run].
 */
interface AgentCommand {
    val descriptor: CommandDescriptor

    /**
     * @return the JSON output for the client, an empty object when there is nothing to report.
     * @throws AgentError to report a failure with a stable code.
     */
    suspend fun run(arguments: JsonObject): JsonElement
}

/** A failure to report to the client. Mirrors `AgentError` in Hammer. */
class AgentError(
    message: String,
    val code: String = AgentErrorCode.FAILED,
    val hint: String? = null,
) : Exception(message)
