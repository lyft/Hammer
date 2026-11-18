package com.lyft.hammer.agent

/** The sockets agents in this process listen on, so a second agent's error can say why it can't. */
internal class ListeningSockets {
    private val names = mutableSetOf<String>()

    @Synchronized
    fun add(name: String) {
        names += name
    }

    @Synchronized
    fun remove(name: String) {
        names -= name
    }

    @Synchronized
    fun contains(name: String): Boolean = name in names

    companion object {
        /** The record for this process, which every agent in it shares. */
        val process = ListeningSockets()
    }
}
