package com.lyft.hammer.agent.core

import com.lyft.hammer.agent.JsonValue
import java.util.Base64

/** A command's image output, which clients recognize by `"type": "image"`. Mirrors `AgentImage` in Hammer. */
internal object AgentImage {
    fun png(bytes: ByteArray): JsonValue.Object = jsonObject(
        "type" to "image".json,
        "mimeType" to "image/png".json,
        "data" to Base64.getEncoder().encodeToString(bytes).json,
    )
}
