package com.lyft.hammer.agent.core

import com.lyft.hammer.agent.JsonValue

internal class JsonSyntaxError(message: String) : Exception(message)

/** Reads and writes [JsonValue]s as JSON text, the way Hammer's `JSONDecoder` and `JSONEncoder` do. */
internal object Json {

    /** Deeper input is refused, so a request can't overflow the stack. Foundation's JSON limit too. */
    const val MAX_DEPTH = 512

    /** @throws JsonSyntaxError if [text] isn't one JSON value or nests deeper than [MAX_DEPTH]. */
    fun parse(text: String): JsonValue = Parser(text).document()

    /**
     * The JSON text of [value]. Whole numbers are written without a fraction, as Hammer's encoder does.
     *
     * @throws IllegalArgumentException for a number JSON can't hold, such as NaN.
     */
    fun encode(value: JsonValue): String = StringBuilder().also { write(value, it) }.toString()

    private fun write(value: JsonValue, out: StringBuilder) {
        when (value) {
            JsonValue.Null -> out.append("null")
            is JsonValue.Bool -> out.append(value.value)
            is JsonValue.Number -> out.append(number(value.value))
            is JsonValue.String -> string(value.value, out)
            is JsonValue.Array -> {
                out.append('[')
                value.values.forEachIndexed { index, element ->
                    if (index > 0) out.append(',')
                    write(element, out)
                }
                out.append(']')
            }
            is JsonValue.Object -> {
                out.append('{')
                value.values.entries.forEachIndexed { index, (key, element) ->
                    if (index > 0) out.append(',')
                    string(key, out)
                    out.append(':')
                    write(element, out)
                }
                out.append('}')
            }
        }
    }

    private fun number(value: Double): String {
        require(value.isFinite()) { "JSON can't hold the number $value" }
        return if (value % 1.0 == 0.0 && value in WHOLE_RANGE) value.toLong().toString() else value.toString()
    }

    private fun string(value: String, out: StringBuilder) {
        out.append('"')
        for (character in value) {
            when (character) {
                '"' -> out.append("\\\"")
                '\\' -> out.append("\\\\")
                '\n' -> out.append("\\n")
                '\r' -> out.append("\\r")
                '\t' -> out.append("\\t")
                '\b' -> out.append("\\b")
                '\u000C' -> out.append("\\f")
                // Line and paragraph separators end lines in JavaScript, so they stay escaped too
                ' ', ' ' -> out.append(String.format("\\u%04x", character.code))
                else -> if (character < ' ') out.append(String.format("\\u%04x", character.code)) else out.append(character)
            }
        }
        out.append('"')
    }

    private val WHOLE_RANGE = -9.007199254740992E15..9.007199254740992E15

    private class Parser(private val text: String) {
        private var index = 0

        fun document(): JsonValue {
            val value = value(depth = 1)
            skipWhitespace()
            if (index < text.length) fail("Unexpected text after the JSON value")
            return value
        }

        private fun value(depth: Int): JsonValue {
            if (depth > MAX_DEPTH) fail("The JSON nests deeper than $MAX_DEPTH levels")
            skipWhitespace()
            if (index >= text.length) fail("Unexpected end of the JSON")
            return when (val character = text[index]) {
                '{' -> objectValue(depth)
                '[' -> arrayValue(depth)
                '"' -> JsonValue.String(string())
                't' -> literal("true", JsonValue.Bool(true))
                'f' -> literal("false", JsonValue.Bool(false))
                'n' -> literal("null", JsonValue.Null)
                else -> if (character == '-' || character in '0'..'9') number() else fail("Unexpected character '$character'")
            }
        }

        private fun objectValue(depth: Int): JsonValue.Object {
            index++
            val values = LinkedHashMap<String, JsonValue>()
            skipWhitespace()
            if (peek() == '}') {
                index++
                return JsonValue.Object(values)
            }
            while (true) {
                skipWhitespace()
                if (peek() != '"') fail("Expected a key in quotes")
                val key = string()
                skipWhitespace()
                expect(':')
                values[key] = value(depth + 1)
                skipWhitespace()
                when (next()) {
                    ',' -> continue
                    '}' -> return JsonValue.Object(values)
                    else -> fail("Expected ',' or '}' in an object")
                }
            }
        }

        private fun arrayValue(depth: Int): JsonValue.Array {
            index++
            val values = mutableListOf<JsonValue>()
            skipWhitespace()
            if (peek() == ']') {
                index++
                return JsonValue.Array(values)
            }
            while (true) {
                values += value(depth + 1)
                skipWhitespace()
                when (next()) {
                    ',' -> continue
                    ']' -> return JsonValue.Array(values)
                    else -> fail("Expected ',' or ']' in an array")
                }
            }
        }

        private fun string(): String {
            index++
            val out = StringBuilder()
            while (true) {
                val character = next() ?: fail("Unterminated string")
                when {
                    character == '"' -> return out.toString()
                    character == '\\' -> out.append(escape())
                    character < ' ' -> fail("Unescaped control character in a string")
                    else -> out.append(character)
                }
            }
        }

        private fun escape(): Char = when (val character = next()) {
            '"' -> '"'
            '\\' -> '\\'
            '/' -> '/'
            'b' -> '\b'
            'f' -> '\u000C'
            'n' -> '\n'
            'r' -> '\r'
            't' -> '\t'
            'u' -> {
                if (index + HEX_DIGITS > text.length) fail("Incomplete \\u escape")
                val code = text.substring(index, index + HEX_DIGITS).toIntOrNull(HEX_RADIX) ?: fail("Invalid \\u escape")
                index += HEX_DIGITS
                code.toChar()
            }
            else -> fail("Invalid escape \\$character")
        }

        private fun number(): JsonValue.Number {
            val start = index
            if (peek() == '-') index++
            if (peek() == '0') index++ else digits()
            if (peek() == '.') {
                index++
                digits()
            }
            if (peek() == 'e' || peek() == 'E') {
                index++
                if (peek() == '+' || peek() == '-') index++
                digits()
            }
            return JsonValue.Number(text.substring(start, index).toDouble())
        }

        private fun digits() {
            val start = index
            while (peek()?.let { it in '0'..'9' } == true) index++
            if (index == start) fail("Expected a digit")
        }

        private fun literal(word: String, value: JsonValue): JsonValue {
            if (!text.startsWith(word, index)) fail("Unexpected character '${text[index]}'")
            index += word.length
            return value
        }

        private fun expect(character: Char) {
            if (next() != character) fail("Expected '$character'")
        }

        private fun skipWhitespace() {
            while (peek()?.let { it == ' ' || it == '\n' || it == '\r' || it == '\t' } == true) index++
        }

        private fun peek(): Char? = text.getOrNull(index)

        private fun next(): Char? = text.getOrNull(index)?.also { index++ }

        private fun fail(message: String): Nothing = throw JsonSyntaxError("$message at offset $index")
    }

    private const val HEX_DIGITS = 4
    private const val HEX_RADIX = 16
}

/** Builds an object from [entries], leaving out the ones whose value is null. */
internal fun jsonObject(vararg entries: Pair<String, JsonValue?>): JsonValue.Object =
    JsonValue.Object(LinkedHashMap<String, JsonValue>().also { map -> entries.forEach { (key, value) -> if (value != null) map[key] = value } })

internal val String.json: JsonValue.String get() = JsonValue.String(this)
internal val Boolean.json: JsonValue.Bool get() = JsonValue.Bool(this)
internal val Number.json: JsonValue.Number get() = JsonValue.Number(this.toDouble())

/** The empty object, a command's output when it has nothing to report. */
internal val emptyJsonObject: JsonValue.Object = JsonValue.Object(emptyMap())
