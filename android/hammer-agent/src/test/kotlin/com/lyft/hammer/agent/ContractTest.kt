package com.lyft.hammer.agent

import com.lyft.hammer.agent.core.BuiltinCommands
import com.lyft.hammer.agent.core.Json
import org.assertj.core.api.Assertions.assertThat
import org.junit.Test
import java.io.File

/**
 * Checks the agent against the files Hammer's Swift tests write to `android/contract/`. When one
 * fails, the Swift side changed: update the agent to match, or regenerate the files if the change is
 * meant for Android too.
 */
class ContractTest {

    @Test
    fun builtinCommands_matchTheContract() {
        val expected = normalized(contract("builtin-commands.json"))

        val actual = normalized(JsonValue.Array(BuiltinCommands.all.map { it.toJson() }))

        assertThat(actual).isEqualTo(expected)
    }

    @Test
    fun reservedParameterNames_matchTheContract() {
        val expected = contract("reserved-parameter-names.json").arrayValue.orEmpty().map { it.stringValue }

        assertThat(CommandDescriptor.reservedParameterNames.sorted()).isEqualTo(expected)
    }

    @Test
    fun errorCodes_matchTheContract() {
        val expected = contract("error-codes.json").arrayValue.orEmpty().map { it.stringValue }
        val actual = AgentErrorCode::class.java.declaredFields
            .filter { it.type == String::class.java && java.lang.reflect.Modifier.isStatic(it.modifiers) }
            .map { it.get(null) as String }

        assertThat(actual).containsExactlyInAnyOrderElementsOf(expected)
    }

    private fun contract(name: String): JsonValue = Json.parse(File(CONTRACT, name).readText())

    // Missing parameters and examples mean empty, as the HTTP API spec says
    private fun normalized(commands: JsonValue): List<JsonValue.Object> = commands.arrayValue.orEmpty().map { command ->
        val values = LinkedHashMap(command.objectValue?.values.orEmpty())
        values.putIfAbsent("parameters", JsonValue.Array())
        values.putIfAbsent("examples", JsonValue.Array())
        JsonValue.Object(values)
    }

    private companion object {
        // Unit tests run in the module's directory
        val CONTRACT = File("../contract")
    }
}
