package com.lyft.hammer.agent.core

import com.lyft.hammer.agent.CommandDescriptor
import com.lyft.hammer.agent.JsonValue
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatCode
import org.assertj.core.api.Assertions.catchThrowableOfType
import org.junit.Test

class ArgumentValidationTest {

    private val descriptor = CommandDescriptor(
        name = "swipe",
        summary = "Swipes.",
        parameters = listOf(
            CommandDescriptor.Parameter("direction", CommandDescriptor.ParameterType.Choice(listOf("up", "down")), "", isRequired = true),
            CommandDescriptor.Parameter("count", CommandDescriptor.ParameterType.IntegerValue, ""),
            CommandDescriptor.Parameter("traits", CommandDescriptor.ParameterType.StringList, ""),
        ),
    )

    private val hint = "swipe takes direction (required): one of up, down; count: an integer; traits: a list of strings"

    @Test
    fun validate_validArguments_doesNotThrow() {
        assertThatCode { descriptor.validate(json("""{"direction": "up", "count": 2.0, "traits": ["a", "b"]}""")) }
            .doesNotThrowAnyException()
    }

    @Test
    fun validate_unknownArgumentCloseToParameter_suggestsIt() {
        val error = validationError("""{"direction": "up", "cuont": 1}""")

        assertThat(error.description).isEqualTo("Unknown argument \"cuont\" for swipe, did you mean \"count\"?")
        assertThat(error.hint).isEqualTo(hint)
    }

    @Test
    fun validate_unknownArgumentFarFromParameters_hasNoSuggestion() {
        val error = validationError("""{"direction": "up", "velocity": 1}""")

        assertThat(error.description).isEqualTo("Unknown argument \"velocity\" for swipe")
    }

    @Test
    fun validate_fractionalInteger_rejectsIt() {
        val error = validationError("""{"direction": "up", "count": 1.5}""")

        assertThat(error.description).isEqualTo("Invalid value 1.5 for \"count\", expected an integer")
    }

    @Test
    fun validate_choiceOutsideValues_rejectsIt() {
        val error = validationError("""{"direction": "left"}""")

        assertThat(error.description).isEqualTo("Invalid value \"left\" for \"direction\", expected one of up, down")
    }

    @Test
    fun validate_listWithNonString_rejectsIt() {
        val error = validationError("""{"direction": "up", "traits": ["a", 1]}""")

        assertThat(error.description).isEqualTo("Invalid value [\"a\",1] for \"traits\", expected a list of strings")
    }

    @Test
    fun validate_missingRequired_namesIt() {
        val error = validationError("""{"count": 1}""")

        assertThat(error.description).isEqualTo("Missing required argument \"direction\" for swipe, expected one of up, down")
    }

    @Test
    fun validate_severalProblems_reportsFirstArgumentByName() {
        val error = validationError("""{"zeta": 1, "alpha": 1}""")

        assertThat(error.description).isEqualTo("Unknown argument \"alpha\" for swipe")
    }

    @Test
    fun argumentsHint_noParameters_saysSo() {
        assertThat(CommandDescriptor(name = "ping", summary = "").argumentsHint).isEqualTo("ping takes no arguments")
    }

    private fun validationError(arguments: String): ArgumentsError =
        catchThrowableOfType({ descriptor.validate(json(arguments)) }, ArgumentsError::class.java)

    private fun json(value: String): JsonValue.Object = Json.parse(value) as JsonValue.Object
}
