package com.lyft.hammer.agent

import com.google.gson.JsonArray
import com.google.gson.JsonElement
import com.google.gson.JsonObject
import com.google.gson.JsonParseException
import com.google.gson.JsonParser
import com.lyft.hammer.agent.core.AgentCommand
import com.lyft.hammer.agent.core.AgentError
import com.lyft.hammer.agent.core.AgentErrorCode
import com.lyft.hammer.agent.core.ArgumentsError
import com.lyft.hammer.agent.core.CommandDescriptor
import com.lyft.hammer.agent.core.JsonArrays
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

    constructor(commands: List<AgentCommand>) : this(CommandRegistry.of(commands, AgentLog.Logcat))

    private val mutex = Mutex()

    val descriptors: List<CommandDescriptor>
        get() = registry.descriptors

    suspend fun respond(request: HttpRequest): HttpResponse = when {
        request.method == "GET" && request.path == COMMANDS_PATH ->
            HttpResponse.json(HttpResponse.OK, JsonArrays.of(descriptors.map { it.toJson() }))
        request.method == "POST" && request.path.startsWith("$COMMANDS_PATH/") ->
            run(request.path.removePrefix("$COMMANDS_PATH/"), request.body)
        else -> HttpResponse.error(
            HttpResponse.NOT_FOUND,
            AgentErrorCode.INVALID_REQUEST,
            "Unknown route ${request.method} ${request.path}",
        )
    }

    private suspend fun run(name: String, body: ByteArray): HttpResponse {
        val command = registry.command(name) ?: return unknownCommand(name)
        return mutex.withLock {
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

    private fun argumentsObject(body: ByteArray, descriptor: CommandDescriptor): JsonObject {
        if (body.isEmpty()) return JsonObject()
        val parsed = try {
            JsonParser.parseString(body.decodeToString())
        } catch (exception: JsonParseException) {
            null
        }
        return parsed?.takeIf { it.isJsonObject }?.asJsonObject
            ?: throw ArgumentsError("The arguments must be a JSON object", descriptor.argumentsHint)
    }

    /** Hammer encodes output with sorted keys. */
    private fun sorted(element: JsonElement): JsonElement = when {
        element.isJsonObject -> JsonObject().also { sortedObject ->
            element.asJsonObject.entrySet().sortedBy { it.key }.forEach { (key, value) -> sortedObject.add(key, sorted(value)) }
        }
        element.isJsonArray -> JsonArray().also { array -> element.asJsonArray.forEach { array.add(sorted(it)) } }
        else -> element
    }

    companion object {
        const val COMMANDS_PATH = "/commands"
    }
}
