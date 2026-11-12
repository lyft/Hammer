package com.lyft.hammer.agent.core

import com.google.gson.JsonObject
import java.util.Base64

/** A command's image output, which clients recognize by `"type": "image"`. Mirrors `AgentImage` in Hammer. */
internal object AgentImage {
    fun png(bytes: ByteArray): JsonObject = JsonObject().apply {
        addProperty("type", "image")
        addProperty("mimeType", "image/png")
        addProperty("data", Base64.getEncoder().encodeToString(bytes))
    }
}
