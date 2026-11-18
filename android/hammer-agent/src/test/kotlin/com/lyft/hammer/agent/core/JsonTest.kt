package com.lyft.hammer.agent.core

import com.lyft.hammer.agent.JsonValue
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.Test

class JsonTest {

    @Test
    fun parse_everyShape_keepsTheValuesAndKeyOrder() {
        val value = Json.parse(""" {"z": null, "a": [true, false, -1.5e2, "x"], "n": {"k": 0}} """)

        assertThat(value).isEqualTo(
            JsonValue.Object(
                "z" to JsonValue.Null,
                "a" to JsonValue.Array(JsonValue.Bool(true), JsonValue.Bool(false), JsonValue.Number(-150.0), JsonValue.String("x")),
                "n" to JsonValue.Object("k" to JsonValue.Number(0)),
            ),
        )
        assertThat((value as JsonValue.Object).values.keys).containsExactly("z", "a", "n")
    }

    @Test
    fun parse_escapes_decodesThem() {
        val value = Json.parse(""""a\"b\\c\/d\n\té😀"""")

        assertThat(value).isEqualTo(JsonValue.String("a\"b\\c/d\n\té😀"))
    }

    @Test
    fun parse_invalidJson_throws() {
        listOf("", "{", "[1,]", "{\"a\" 1}", "01", "1.", "tru", "'a'", "{a: 1}", "\"tab\there\"", "[] []").forEach { text ->
            assertThatThrownBy { Json.parse(text) }.`as`(text).isInstanceOf(JsonSyntaxError::class.java)
        }
    }

    @Test
    fun parse_atTheDepthLimit_reads() {
        val text = "[".repeat(Json.MAX_DEPTH) + "]".repeat(Json.MAX_DEPTH)

        assertThat(Json.parse(text)).isInstanceOf(JsonValue.Array::class.java)
    }

    @Test
    fun parse_deeperThanTheLimit_throwsInsteadOfOverflowing() {
        val text = "[".repeat(100_000) + "]".repeat(100_000)

        assertThatThrownBy { Json.parse(text) }
            .isInstanceOf(JsonSyntaxError::class.java)
            .hasMessageContaining("deeper than ${Json.MAX_DEPTH} levels")
    }

    @Test
    fun encode_numbers_writesWholeOnesWithoutAFraction() {
        val value = JsonValue.Array(listOf(2.0, 1.5, -0.25, 1e20, 0.0001).map { JsonValue.Number(it) })

        assertThat(Json.encode(value)).isEqualTo("[2,1.5,-0.25,1.0E20,1.0E-4]")
    }

    @Test
    fun encode_strings_escapesQuotesBackslashesAndControlCharacters() {
        val value = JsonValue.String("\"\\/\n\r\t\b\u000C\u0001 é😀")

        assertThat(Json.encode(value)).isEqualTo("\"\\\"\\\\/\\n\\r\\t\\b\\f\\u0001\\u2028é😀\"")
    }

    @Test
    fun encode_object_keepsKeyOrderWithoutSpaces() {
        val value = jsonObject("b" to 1.json, "a" to JsonValue.Null, "skipped" to null, "c" to "x".json)

        assertThat(Json.encode(value)).isEqualTo("""{"b":1,"a":null,"c":"x"}""")
    }

    @Test
    fun encode_notFinite_throws() {
        assertThatThrownBy { Json.encode(JsonValue.Number(Double.NaN)) }.isInstanceOf(IllegalArgumentException::class.java)
    }

    @Test
    fun encode_thenParse_isTheSameValue() {
        val value = JsonValue.Object("count" to JsonValue.Number(2), "names" to JsonValue.Array(JsonValue.String("a\"b")))

        assertThat(Json.parse(Json.encode(value))).isEqualTo(value)
    }
}
