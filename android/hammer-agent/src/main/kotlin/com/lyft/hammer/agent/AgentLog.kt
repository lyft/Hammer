package com.lyft.hammer.agent

import android.util.Log

/** Where the agent writes its few log lines, so tests can read them. */
internal interface AgentLog {
    fun info(message: String)

    fun warning(message: String, error: Throwable? = null)

    fun error(message: String, error: Throwable? = null)

    /** Logcat, with the tag `Hammer`. */
    object Logcat : AgentLog {
        private const val TAG = "Hammer"

        // Info is loggable unless the device lowers the tag's level, and the agent's info lines are the ones to keep
        override fun info(message: String) {
            if (Log.isLoggable(TAG, Log.INFO)) Log.i(TAG, message)
        }

        override fun warning(message: String, error: Throwable?) {
            Log.w(TAG, message, error)
        }

        override fun error(message: String, error: Throwable?) {
            Log.e(TAG, message, error)
        }
    }
}
