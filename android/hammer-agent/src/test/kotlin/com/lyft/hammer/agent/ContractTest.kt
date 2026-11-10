package com.lyft.hammer.agent

import com.google.gson.JsonArray
import com.google.gson.JsonElement
import com.google.gson.JsonObject
import com.google.gson.JsonParser
import com.lyft.hammer.agent.core.BuiltinCommands
import com.lyft.hammer.agent.core.JsonArrays
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

        val actual = normalized(JsonArrays.of(BuiltinCommands.all.map { it.toJson() }))

        assertThat(actual).isEqualTo(expected)
    }

    @Test
    fun reservedParameterNames_matchTheContract() {
        val expected = contract("reserved-parameter-names.json").asJsonArray.map { it.asString }

        assertThat(CommandDescriptor.reservedParameterNames.sorted()).isEqualTo(expected)
    }

    @Test
    fun errorCodes_matchTheContract() {
        val expected = contract("error-codes.json").asJsonArray.map { it.asString }
        val actual = AgentErrorCode::class.java.declaredFields
            .filter { it.type == String::class.java && java.lang.reflect.Modifier.isStatic(it.modifiers) }
            .map { it.get(null) as String }

        assertThat(actual).containsExactlyInAnyOrderElementsOf(expected)
    }

    private fun contract(name: String): JsonElement = JsonParser.parseString(File(CONTRACT, name).readText())

    // Missing parameters and examples mean empty, as the HTTP API spec says
    private fun normalized(commands: JsonElement): JsonArray = JsonArray().apply {
        commands.asJsonArray.forEach { command ->
            add(
                command.asJsonObject.deepCopy().apply {
                    if (!has("parameters")) add("parameters", JsonArray())
                    if (!has("examples")) add("examples", JsonArray())
                },
            )
        }
    }

    private companion object {
        // Unit tests run in the module's directory
        val CONTRACT = File("../contract")
    }
}
