package com.lyft.hammer.agent.core

import com.google.gson.JsonElement
import com.google.gson.JsonObject
import com.google.gson.JsonPrimitive

/**
 * Describes a command the agent runs, for clients to list, validate and document it. Mirrors
 * `CommandDescriptor` in Hammer's `HammerAgentCore`; [toJson] is the shape `GET /commands` returns.
 */
data class CommandDescriptor(
    val name: String,
    val summary: String,
    val parameters: List<Parameter> = emptyList(),
    val examples: List<Example> = emptyList(),
) {
    data class Parameter(
        val name: String,
        val type: ParameterType,
        val summary: String,
        val isRequired: Boolean = false,
    )

    data class Example(
        val summary: String,
        val arguments: Map<String, JsonElement> = emptyMap(),
    )

    sealed class ParameterType(val wireName: String, val expectation: String) {
        data object StringValue : ParameterType("string", "a string")
        data object IntegerValue : ParameterType("integer", "an integer")
        data object NumberValue : ParameterType("number", "a number")
        data object BooleanValue : ParameterType("boolean", "true or false")
        data object StringList : ParameterType("stringList", "a list of strings")
        data class Choice(val values: List<String>) : ParameterType("choice", "one of " + values.joinToString(", "))

        /** Any JSON value. */
        data object Json : ParameterType("json", "any JSON value")
    }

    fun toJson(): JsonObject = JsonObject().apply {
        addProperty("name", name)
        addProperty("summary", summary)
        add("parameters", JsonArrays.of(parameters.map { it.toJson() }))
        add("examples", JsonArrays.of(examples.map { it.toJson() }))
    }

    companion object {
        /**
         * The parameter names clients use for their own options, such as the `hammer` tool's `--output`.
         * Mirrors `CommandDescriptor.reservedParameterNames(for: .android)` in Hammer.
         */
        val RESERVED_PARAMETER_NAMES = setOf("output", "port", "system", "udid", "android", "serial", "app_id")
    }
}

private fun CommandDescriptor.Parameter.toJson(): JsonObject = JsonObject().apply {
    addProperty("name", name)
    add("type", type.toJson())
    addProperty("summary", summary)
    addProperty("isRequired", isRequired)
}

private fun CommandDescriptor.ParameterType.toJson(): JsonObject = JsonObject().apply {
    addProperty("type", wireName)
    if (this@toJson is CommandDescriptor.ParameterType.Choice) {
        add("values", JsonArrays.of(values.map { JsonPrimitive(it) }))
    }
}

private fun CommandDescriptor.Example.toJson(): JsonObject = JsonObject().apply {
    addProperty("summary", summary)
    add("arguments", JsonObject().also { json -> arguments.forEach { (name, value) -> json.add(name, value) } })
}
