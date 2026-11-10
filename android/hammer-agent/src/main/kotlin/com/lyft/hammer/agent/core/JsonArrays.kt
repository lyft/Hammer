package com.lyft.hammer.agent.core

import com.google.gson.JsonArray
import com.google.gson.JsonElement

internal object JsonArrays {
    fun of(elements: Iterable<JsonElement>): JsonArray = JsonArray().also { array -> elements.forEach(array::add) }
}
