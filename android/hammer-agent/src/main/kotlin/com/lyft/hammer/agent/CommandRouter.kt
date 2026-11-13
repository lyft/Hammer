package com.lyft.hammer.agent

import com.lyft.hammer.agent.core.ArgumentsError
import com.lyft.hammer.agent.core.Json
import com.lyft.hammer.agent.core.JsonSyntaxError
import com.lyft.hammer.agent.core.WireCommand
import com.lyft.hammer.agent.core.argumentsHint
import com.lyft.hammer.agent.core.closestMatch
import com.lyft.hammer.agent.core.validate
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/**
 * Routes requests to commands and runs them one at a time, so gestures never interleave. Ports
 * Hammer's `CommandRouter` and `ErrorReport`, so both agents answer a request the same way.
 */
internal class CommandRouter(private val registry: CommandRegistry) {

    constructor(commands: List<WireCommand>) : this(CommandRegistry.of(commands, AgentLog.Logcat))

    private val mutex = Mutex()

    val descriptors: List<CommandDescriptor>
        get() = registry.descriptors

    /**
     * The response to [request], or null when [isClientGone] says its client closed the connection
     * before the request ran, including while it waited for another command to finish.
     */
    suspend fun respond(request: HttpRequest, isClientGone: () -> Boolean): HttpResponse? = when {
        isClientGone() -> null
        request.method == "GET" && request.path == COMMANDS_PATH ->
            HttpResponse.json(HttpResponse.OK, JsonValue.Array(descriptors.map { it.toJson() }))
        request.method == "POST" && request.path.startsWith("$COMMANDS_PATH/") ->
            run(request.path.removePrefix("$COMMANDS_PATH/"), request.body, isClientGone)
        else -> HttpResponse.error(
            HttpResponse.NOT_FOUND,
            AgentErrorCode.INVALID_REQUEST,
            "Unknown route ${request.method} ${request.path}",
        )
    }

    private suspend fun run(name: String, body: ByteArray, isClientGone: () -> Boolean): HttpResponse? {
        val command = registry.command(name) ?: return unknownCommand(name)
        return mutex.withLock {
            if (isClientGone()) return@withLock null
            try {
                val arguments = argumentsObject(body, command.descriptor)
                command.descriptor.validate(arguments)
                HttpResponse.json(HttpResponse.OK, sorted(command.run(arguments)))
            } catch (error: ArgumentsError) {
                HttpResponse.error(HttpResponse.BAD_REQUEST, AgentErrorCode.INVALID_ARGUMENTS, error.description, error.hint)
            } catch (error: AgentError) {
                val status = if (error.code == AgentErrorCode.INVALID_ARGUMENTS) HttpResponse.BAD_REQUEST else HttpResponse.INTERNAL_SERVER_ERROR
                HttpResponse.error(status, error.code, error.message.orEmpty(), error.hint)
            } catch (error: Exception) {
                currentCoroutineContext().ensureActive()
                HttpResponse.error(HttpResponse.INTERNAL_SERVER_ERROR, AgentErrorCode.FAILED, error.message ?: error.toString())
            }
        }
    }

    private fun unknownCommand(name: String): HttpResponse {
        val order = registry.names
        val suggestion = closestMatch(name, order)?.let { ", did you mean $it?" }.orEmpty()
        return HttpResponse.error(
            HttpResponse.NOT_FOUND,
            AgentErrorCode.UNKNOWN_COMMAND,
            "Unknown command \"$name\"$suggestion",
            "The commands are ${order.joinToString(", ")}",
        )
    }

    private fun argumentsObject(body: ByteArray, descriptor: CommandDescriptor): JsonValue.Object {
        if (body.isEmpty()) return JsonValue.Object(emptyMap())
        val parsed = try {
            Json.parse(body.decodeToString())
        } catch (error: JsonSyntaxError) {
            throw ArgumentsError("The arguments must be a JSON object: ${error.message}", descriptor.argumentsHint)
        }
        return parsed as? JsonValue.Object ?: throw ArgumentsError("The arguments must be a JSON object", descriptor.argumentsHint)
    }

    /** Hammer encodes output with sorted keys. */
    private fun sorted(value: JsonValue): JsonValue = when (value) {
        is JsonValue.Object -> JsonValue.Object(value.values.entries.sortedBy { it.key }.associateTo(LinkedHashMap()) { (key, element) -> key to sorted(element) })
        is JsonValue.Array -> JsonValue.Array(value.values.map(::sorted))
        else -> value
    }

    companion object {
        const val COMMANDS_PATH = "/commands"
    }
}
