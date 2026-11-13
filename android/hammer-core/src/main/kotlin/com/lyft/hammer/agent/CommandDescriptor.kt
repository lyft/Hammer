package com.lyft.hammer.agent

import com.lyft.hammer.agent.core.json
import com.lyft.hammer.agent.core.jsonObject

/**
 * Describes a command the agent runs, for clients to list, validate and document it. Mirrors
 * `CommandDescriptor` in Hammer's `HammerAgentCore`.
 *
 * @property name the name clients call the command with, in snake case.
 * @property summary what the command does, written for the agents and people that call it.
 * @property parameters the parameters of the command's arguments object.
 * @property examples typical uses of the command, to show agents and people how to call it.
 */
public data class CommandDescriptor(
    public val name: String,
    public val summary: String,
    public val parameters: List<Parameter> = emptyList(),
    public val examples: List<Example> = emptyList(),
) {
    /**
     * A parameter of a command.
     *
     * @property name the name of the argument.
     * @property type the type of the argument's value.
     * @property summary what the argument does.
     * @property isRequired if the argument must be passed.
     */
    public data class Parameter(
        public val name: String,
        public val type: ParameterType,
        public val summary: String,
        public val isRequired: Boolean = false,
    )

    /**
     * A typical use of a command.
     *
     * @property summary what the example does.
     * @property arguments the arguments object.
     */
    public data class Example(
        public val summary: String,
        public val arguments: Map<String, JsonValue> = emptyMap(),
    )

    /**
     * The type of a parameter's value. Clients decode a type they don't know as [Json], so apps can use
     * newer types than their clients.
     */
    public sealed class ParameterType(internal val wireName: String, internal val expectation: String) {
        /** A string. */
        public data object StringValue : ParameterType("string", "a string")

        /** A whole number. */
        public data object IntegerValue : ParameterType("integer", "an integer")

        /** A number. */
        public data object NumberValue : ParameterType("number", "a number")

        /** `true` or `false`. */
        public data object BooleanValue : ParameterType("boolean", "true or false")

        /** An array of strings. */
        public data object StringList : ParameterType("stringList", "a list of strings")

        /** One of [values]. */
        public data class Choice(public val values: List<String>) :
            ParameterType("choice", "one of " + values.joinToString(", "))

        /** Any JSON value, such as an object for a frame. */
        public data object Json : ParameterType("json", "any JSON value")
    }

    internal fun toJson(): JsonValue.Object = jsonObject(
        "name" to name.json,
        "summary" to summary.json,
        "parameters" to JsonValue.Array(parameters.map { it.toJson() }),
        "examples" to JsonValue.Array(examples.map { it.toJson() }),
    )

    public companion object {
        /**
         * The parameter names clients use for their own options, such as the `hammer` tool's `--output`
         * and `--serial`. Mirrors `CommandDescriptor.reservedParameterNames(for: .android)` in Hammer.
         */
        public val reservedParameterNames: Set<String> =
            setOf("output", "port", "system", "udid", "android", "serial", "app_id")
    }
}

private fun CommandDescriptor.Parameter.toJson(): JsonValue.Object = jsonObject(
    "name" to name.json,
    "type" to type.toJson(),
    "summary" to summary.json,
    "isRequired" to isRequired.json,
)

private fun CommandDescriptor.ParameterType.toJson(): JsonValue.Object = jsonObject(
    "type" to wireName.json,
    "values" to (this as? CommandDescriptor.ParameterType.Choice)?.let { choice -> JsonValue.Array(choice.values.map { it.json }) },
)

private fun CommandDescriptor.Example.toJson(): JsonValue.Object =
    jsonObject("summary" to summary.json, "arguments" to JsonValue.Object(arguments))
