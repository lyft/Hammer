package com.lyft.hammer.agent

internal class RecordingLog : AgentLog {
    val lines = mutableListOf<String>()

    override fun info(message: String) {
        lines += "I $message"
    }

    override fun warning(message: String, error: Throwable?) {
        lines += "W $message"
    }

    override fun error(message: String, error: Throwable?) {
        lines += "E $message"
    }
}
