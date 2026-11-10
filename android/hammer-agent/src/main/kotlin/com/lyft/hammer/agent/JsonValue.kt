package com.lyft.hammer.agent

/**
 * A JSON value of any shape, such as a command's arguments or output. Mirrors `JSONValue` in Hammer.
 *
 * Numbers are doubles, as in JSON, so integers are exact up to 2^53.
 */
public sealed interface JsonValue {

    /** JSON's `null`. */
    public data object Null : JsonValue

    /** `true` or `false`. */
    public data class Bool(val value: Boolean) : JsonValue

    /** A number. */
    public data class Number(val value: Double) : JsonValue {
        /** Creates a number from an integer. */
        public constructor(value: Int) : this(value.toDouble())
    }

    /** A string. */
    public data class String(val value: kotlin.String) : JsonValue

    /** An array of values. */
    public data class Array(val values: List<JsonValue>) : JsonValue {
        /** Creates an array of [values]. */
        public constructor(vararg values: JsonValue) : this(values.toList())
    }

    /** An object, whose keys keep their order. */
    public data class Object(val values: Map<kotlin.String, JsonValue>) : JsonValue {
        /** Creates an object with [entries], such as `JsonValue.Object("user" to JsonValue.String("test"))`. */
        public constructor(vararg entries: Pair<kotlin.String, JsonValue>) : this(linkedMapOf(*entries))

        /** The value for [key], or null if the object has none. */
        public operator fun get(key: kotlin.String): JsonValue? = values[key]
    }

    /** The string, or null if the value is not one. */
    public val stringValue: kotlin.String?
        get() = (this as? String)?.value

    /** The number, or null if the value is not one. */
    public val numberValue: Double?
        get() = (this as? Number)?.value

    /** The boolean, or null if the value is not one. */
    public val boolValue: Boolean?
        get() = (this as? Bool)?.value

    /** The array's values, or null if the value is not an array. */
    public val arrayValue: List<JsonValue>?
        get() = (this as? Array)?.values

    /** The object, or null if the value is not one. */
    public val objectValue: Object?
        get() = this as? Object
}
