package com.lyft.hammer.agent.core

import com.google.gson.JsonElement
import com.google.gson.JsonObject
import com.lyft.hammer.agent.CommandDescriptor

/** A problem with a command's arguments, explained so the caller can correct them. */
internal class ArgumentsError(val description: String, val hint: String) : Exception(description)

/**
 * Checks that [arguments] are declared, have their parameter's type and include the required ones.
 * Ports `CommandDescriptor.validate(_:style:)` from Hammer's `HammerAgentCore` with the `.tools` style,
 * so both agents word their errors the same.
 *
 * @throws ArgumentsError naming the argument and what it expects.
 */
internal fun CommandDescriptor.validate(arguments: JsonObject) {
    for ((name, value) in arguments.entrySet().sortedBy { it.key }) {
        val parameter = parameters.firstOrNull { it.name == name }
        if (parameter == null) {
            val suggestion = closestMatch(name, parameters.map { it.name })?.let { ", did you mean \"$it\"?" }.orEmpty()
            throw ArgumentsError("Unknown argument \"$name\" for ${this.name}$suggestion", argumentsHint)
        }
        if (!parameter.type.accepts(value)) {
            throw ArgumentsError(
                "Invalid value $value for \"$name\", expected ${parameter.type.expectation}",
                argumentsHint,
            )
        }
    }
    parameters.firstOrNull { it.isRequired && !arguments.has(it.name) }?.let { missing ->
        throw ArgumentsError(
            "Missing required argument \"${missing.name}\" for $name, expected ${missing.type.expectation}",
            argumentsHint,
        )
    }
}

/** Lists the arguments the command takes, to show next to an argument error. */
internal val CommandDescriptor.argumentsHint: String
    get() {
        if (parameters.isEmpty()) return "$name takes no arguments"
        return "$name takes " + parameters.joinToString("; ") { parameter ->
            "${parameter.name}${if (parameter.isRequired) " (required)" else ""}: ${parameter.type.expectation}"
        }
    }

private fun CommandDescriptor.ParameterType.accepts(value: JsonElement): Boolean = when (this) {
    CommandDescriptor.ParameterType.Json -> true
    CommandDescriptor.ParameterType.StringValue -> value.isJsonPrimitive && value.asJsonPrimitive.isString
    CommandDescriptor.ParameterType.NumberValue -> value.isJsonPrimitive && value.asJsonPrimitive.isNumber
    CommandDescriptor.ParameterType.BooleanValue -> value.isJsonPrimitive && value.asJsonPrimitive.isBoolean
    CommandDescriptor.ParameterType.IntegerValue ->
        value.isJsonPrimitive && value.asJsonPrimitive.isNumber && value.asDouble.let { Math.rint(it) == it }
    CommandDescriptor.ParameterType.StringList ->
        value.isJsonArray && value.asJsonArray.all { it.isJsonPrimitive && it.asJsonPrimitive.isString }
    is CommandDescriptor.ParameterType.Choice ->
        value.isJsonPrimitive && value.asJsonPrimitive.isString && value.asString in values
}

/** The candidate closest to [name], to suggest it for a typo, or null if none is close. */
internal fun closestMatch(name: String, candidates: List<String>): String? {
    val (candidate, distance) = candidates
        .map { it to editDistance(name.lowercase(), it.lowercase()) }
        .minByOrNull { it.second } ?: return null
    return candidate.takeIf { distance <= maxOf(2, name.length / 3) }
}

private fun editDistance(lhs: String, rhs: String): Int {
    var previous = IntArray(rhs.length + 1) { it }
    lhs.forEachIndexed { i, lhsCharacter ->
        val current = IntArray(rhs.length + 1)
        current[0] = i + 1
        rhs.forEachIndexed { j, rhsCharacter ->
            val substitution = previous[j] + if (lhsCharacter == rhsCharacter) 0 else 1
            current[j + 1] = minOf(previous[j + 1] + 1, current[j] + 1, substitution)
        }
        previous = current
    }
    return previous[rhs.length]
}
