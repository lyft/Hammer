package com.lyft.hammer.agent.core

import com.lyft.hammer.agent.CommandDescriptor
import com.lyft.hammer.agent.JsonValue

/**
 * A command as the router runs it, on the request's JSON. The built-in commands implement it directly,
 * and the app's [com.lyft.hammer.agent.AgentCommand]s are adapted to it.
 */
internal interface WireCommand {
    val descriptor: CommandDescriptor

    /**
     * @return the JSON output for the client, an empty object when there is nothing to report.
     * @throws com.lyft.hammer.agent.AgentError to report a failure with a stable code.
     */
    suspend fun run(arguments: JsonValue.Object): JsonValue
}
