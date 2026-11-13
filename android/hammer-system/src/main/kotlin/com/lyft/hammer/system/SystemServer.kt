package com.lyft.hammer.system

import android.app.Activity
import android.app.Instrumentation
import android.accessibilityservice.AccessibilityServiceInfo
import android.app.UiAutomation
import android.os.Bundle
import android.util.Log
import com.lyft.hammer.agent.AgentLog
import com.lyft.hammer.agent.CommandRouter
import com.lyft.hammer.agent.ConnectionHandler
import com.lyft.hammer.agent.SocketListener
import com.lyft.hammer.agent.core.WireCommand
import java.io.IOException
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * Holds UiAutomation and answers the hammer tool's whole-screen commands on the abstract socket
 * [SOCKET_NAME], until the tool stops it or it goes [idle][IDLE_ARGUMENT] for ten minutes.
 *
 * The tool starts it with `am instrument` without `-w`, so it keeps running after adb returns. It writes why it
 * couldn't start to logcat with the tag [TAG], where the tool reads it.
 */
public class SystemServer : Instrumentation() {

    private val stopped = CountDownLatch(1)
    private var idleMillis = DEFAULT_IDLE_MINUTES * MILLIS_PER_MINUTE

    override fun onCreate(arguments: Bundle?) {
        super.onCreate(arguments)
        arguments?.getString(IDLE_ARGUMENT)?.toLongOrNull()?.let { idleMillis = it * MILLIS_PER_MINUTE }
        start()
    }

    override fun onStart() {
        val results = Bundle()
        try {
            serve()
        } catch (error: HelperStartError) {
            Log.e(TAG, error.message.orEmpty())
            results.putString(RESULT_ERROR, error.message)
        }
        finish(Activity.RESULT_OK, results)
    }

    private fun serve() {
        val automation = connect()
        val session = SystemSession(automation, context, stop = { stopped.countDown() })
        val listener = try {
            SocketListener(SOCKET_NAME, handler(session.commands), AgentLog.Logcat)
        } catch (error: IOException) {
            throw HelperStartError("Another process listens on @$SOCKET_NAME, such as a helper that is still running")
        }
        Log.i(TAG, "Listening on @$SOCKET_NAME")
        try {
            while (!stopped.await(IDLE_CHECK_MILLIS, TimeUnit.MILLISECONDS)) {
                if (session.idleMillis() >= idleMillis) {
                    Log.i(TAG, "Stopping after ${idleMillis / MILLIS_PER_MINUTE} idle minutes")
                    break
                }
            }
        } finally {
            listener.close()
        }
    }

    // Accessibility services such as TalkBack keep running, and the interactive windows are reported so
    // the notification shade, dialogs and the keyboard read with the app
    private fun connect(): UiAutomation {
        val automation = try {
            getUiAutomation(UiAutomation.FLAG_DONT_SUPPRESS_ACCESSIBILITY_SERVICES)
        } catch (error: RuntimeException) {
            throw HelperStartError(
                "UiAutomation is held by another tool, such as uiautomator or a UI test, so the helper can't read the screen: ${error.message}",
            )
        } ?: throw HelperStartError("UiAutomation isn't available")
        automation.serviceInfo = automation.serviceInfo.apply {
            flags = flags or AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS or
                AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS or
                AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS
        }
        return automation
    }

    private class HelperStartError(message: String) : Exception(message)

    public companion object {
        /** The abstract socket the helper listens on. Mirrors `AndroidSystemHelper.socketName` in the tool. */
        public const val SOCKET_NAME: String = "hammer_system"

        /** The logcat tag of the helper's own lines. */
        public const val TAG: String = "HammerSystem"

        /** The `am instrument -e` argument for the idle minutes after which the helper stops. */
        public const val IDLE_ARGUMENT: String = "idle_minutes"

        /** Answers the tool's requests. Only adb's shell user and root may connect, as with the app's agent. */
        internal fun handler(commands: List<WireCommand>): ConnectionHandler = ConnectionHandler(CommandRouter(commands))

        private const val RESULT_ERROR = "error"
        private const val DEFAULT_IDLE_MINUTES = 10L
        private const val MILLIS_PER_MINUTE = 60_000L
        private const val IDLE_CHECK_MILLIS = 5_000L
    }
}
