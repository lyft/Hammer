package com.lyft.hammer.agent

/** A socket that accepts requests until it is closed. */
internal fun interface AgentListener {
    fun close()
}
