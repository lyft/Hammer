package com.lyft.hammer.agent.core

import com.google.gson.JsonArray
import com.google.gson.JsonElement
import com.google.gson.JsonNull
import com.google.gson.JsonObject
import com.google.gson.JsonPrimitive
import com.lyft.hammer.agent.JsonValue

internal fun JsonValue.toGson(): JsonElement = when (this) {
    JsonValue.Null -> JsonNull.INSTANCE
    is JsonValue.Bool -> JsonPrimitive(value)
    // Whole numbers go out without a fraction, as Hammer's encoder writes them
    is JsonValue.Number -> if (value % 1.0 == 0.0 && value in WHOLE_RANGE) JsonPrimitive(value.toLong()) else JsonPrimitive(value)
    is JsonValue.String -> JsonPrimitive(value)
    is JsonValue.Array -> JsonArray().also { array -> values.forEach { array.add(it.toGson()) } }
    is JsonValue.Object -> toGsonObject()
}

internal fun JsonValue.Object.toGsonObject(): JsonObject =
    JsonObject().also { json -> values.forEach { (key, value) -> json.add(key, value.toGson()) } }

internal fun JsonElement.toJsonValue(): JsonValue = when {
    isJsonNull -> JsonValue.Null
    isJsonArray -> JsonValue.Array(asJsonArray.map { it.toJsonValue() })
    isJsonObject -> asJsonObject.toJsonValue()
    asJsonPrimitive.isBoolean -> JsonValue.Bool(asBoolean)
    asJsonPrimitive.isNumber -> JsonValue.Number(asDouble)
    else -> JsonValue.String(asString)
}

internal fun JsonObject.toJsonValue(): JsonValue.Object =
    JsonValue.Object(entrySet().associateTo(LinkedHashMap()) { (key, value) -> key to value.toJsonValue() })

private val WHOLE_RANGE = -9.007199254740992E15..9.007199254740992E15
