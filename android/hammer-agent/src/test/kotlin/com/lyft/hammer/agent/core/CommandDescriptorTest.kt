package com.lyft.hammer.agent.core

import com.lyft.hammer.agent.CommandDescriptor
import com.lyft.hammer.agent.JsonValue
import org.assertj.core.api.Assertions.assertThat
import org.junit.Test

class CommandDescriptorTest {

    @Test
    fun toJson_fullDescriptor_matchesHammerWireShape() {
        val descriptor = CommandDescriptor(
            name = "set_override",
            summary = "Overrides a flag.",
            parameters = listOf(
                CommandDescriptor.Parameter("key", CommandDescriptor.ParameterType.StringValue, "The key.", isRequired = true),
                CommandDescriptor.Parameter("type", CommandDescriptor.ParameterType.Choice(listOf("boolean", "int")), "The type."),
            ),
            examples = listOf(CommandDescriptor.Example("Enable a flag", mapOf("key" to JsonValue.String("my_flag")))),
        )

        assertThat(descriptor.toJson()).isEqualTo(
            Json.parse(
                """
                {
                  "name": "set_override",
                  "summary": "Overrides a flag.",
                  "parameters": [
                    {"name": "key", "type": {"type": "string"}, "summary": "The key.", "isRequired": true},
                    {"name": "type", "type": {"type": "choice", "values": ["boolean", "int"]}, "summary": "The type.", "isRequired": false}
                  ],
                  "examples": [{"summary": "Enable a flag", "arguments": {"key": "my_flag"}}]
                }
                """,
            ),
        )
    }

    @Test
    fun toJson_noParametersOrExamples_encodesEmptyLists() {
        val descriptor = CommandDescriptor(name = "ping", summary = "Pings.")

        assertThat(descriptor.toJson()).isEqualTo(
            Json.parse("""{"name": "ping", "summary": "Pings.", "parameters": [], "examples": []}"""),
        )
    }

    @Test
    fun toJson_everyParameterType_usesHammerTypeNames() {
        val types = listOf(
            CommandDescriptor.ParameterType.StringValue,
            CommandDescriptor.ParameterType.IntegerValue,
            CommandDescriptor.ParameterType.NumberValue,
            CommandDescriptor.ParameterType.BooleanValue,
            CommandDescriptor.ParameterType.StringList,
            CommandDescriptor.ParameterType.Json,
        )
        val descriptor = CommandDescriptor(
            name = "all",
            summary = "All types.",
            parameters = types.map { CommandDescriptor.Parameter(it.wireName, it, "") },
        )

        val typeNames = descriptor.toJson()["parameters"]?.arrayValue.orEmpty()
            .map { it.objectValue?.get("type")?.objectValue?.get("type")?.stringValue }

        assertThat(typeNames).containsExactly("string", "integer", "number", "boolean", "stringList", "json")
    }
}
