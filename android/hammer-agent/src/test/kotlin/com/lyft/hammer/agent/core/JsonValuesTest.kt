package com.lyft.hammer.agent.core

import com.google.gson.JsonParser
import com.lyft.hammer.agent.JsonValue
import org.assertj.core.api.Assertions.assertThat
import org.junit.Test

class JsonValuesTest {

    @Test
    fun toJsonValue_everyShape_keepsTheValueAndKeyOrder() {
        val json = JsonParser.parseString("""{"z": null, "a": [true, 1.5, "x"], "n": {"k": 2}}""")

        assertThat(json.toJsonValue()).isEqualTo(
            JsonValue.Object(
                "z" to JsonValue.Null,
                "a" to JsonValue.Array(JsonValue.Bool(true), JsonValue.Number(1.5), JsonValue.String("x")),
                "n" to JsonValue.Object("k" to JsonValue.Number(2)),
            ),
        )
        assertThat((json.toJsonValue() as JsonValue.Object).values.keys).containsExactly("z", "a", "n")
    }

    @Test
    fun toGson_wholeNumber_hasNoFraction() {
        val value = JsonValue.Object("count" to JsonValue.Number(2), "scale" to JsonValue.Number(1.5))

        assertThat(value.toGson().toString()).isEqualTo("""{"count":2,"scale":1.5}""")
    }

    @Test
    fun toGson_thenBack_isTheSameValue() {
        val value = JsonValue.Array(JsonValue.Null, JsonValue.Bool(false), JsonValue.String("é"), JsonValue.Object())

        assertThat(value.toGson().toJsonValue()).isEqualTo(value)
    }
}
