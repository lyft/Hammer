package com.lyft.hammer.agent

import android.app.Application
import android.net.LocalServerSocket
import android.net.LocalSocket
import android.os.Process
import android.system.ErrnoException
import android.system.Os
import android.system.OsConstants
import android.system.StructPollfd
import android.util.Log
import com.lyft.hammer.agent.core.AgentCommand
import com.lyft.hammer.agent.ui.AgentScreen
import com.lyft.hammer.agent.ui.BuiltinAgentCommands
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import java.io.IOException
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Serves lyft/Hammer's agent HTTP API on the abstract socket `hammer_<applicationId>`, which the
 * `hammer` tool reaches with `adb forward`. One socket per app lets several dev builds run side by side.
 * The app's [commands] join the built-in ones.
 */
class HammerAgentServer(private val commands: Collection<AgentCommand>) {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val started = AtomicBoolean(false)

    fun start(application: Application) {
        // The socket name has no process part, so another process, such as :remote, would take it
        if (Application.getProcessName() != application.packageName) return
        if (started.compareAndSet(false, true)) {
            // The app's commands come after the built-in ones, so one with a built-in's name replaces it
            val builtins = BuiltinAgentCommands(AgentScreen(application)).all
            val handler = ConnectionHandler(CommandRouter(builtins + commands.sortedBy { it.descriptor.name }))
            scope.launch { serve(socketName(application.packageName), handler) }
        }
    }

    private fun serve(socketName: String, handler: ConnectionHandler) {
        val server = try {
            LocalServerSocket(socketName)
        } catch (exception: IOException) {
            Log.e(TAG, "Hammer agent failed to bind $socketName; another process of this app may already own it", exception)
            return
        }
        if (Log.isLoggable(TAG, Log.INFO)) {
            Log.i(TAG, "Hammer agent listening on @$socketName, adb and this app can control it")
        }
        try {
            while (true) {
                val socket = server.accept()
                scope.launch { serve(socket, handler) }
            }
        } catch (exception: IOException) {
            Log.e(TAG, "Hammer agent stopped; restart the app to restore it", exception)
        } finally {
            server.close()
        }
    }

    private suspend fun serve(socket: LocalSocket, handler: ConnectionHandler) {
        socket.use {
            try {
                socket.soTimeout = READ_TIMEOUT_MILLIS
                handler.respond(socket.inputStream, socket.outputStream, socket.peerCredentials.uid, Process.myUid()) {
                    isClosedByClient(socket)
                }
            } catch (exception: IOException) {
                Log.w(TAG, "Hammer agent connection failed", exception)
            }
        }
    }

    // Readable with nothing to read is the end of the stream, so the client closed its side
    private fun isClosedByClient(socket: LocalSocket): Boolean = try {
        val poll = StructPollfd().apply {
            fd = socket.fileDescriptor
            events = OsConstants.POLLIN.toShort()
        }
        Os.poll(arrayOf(poll), 0)
        val events = poll.revents.toInt()
        events and OsConstants.POLLHUP != 0 || (events and OsConstants.POLLIN != 0 && socket.inputStream.available() == 0)
    } catch (exception: ErrnoException) {
        false
    }

    companion object {
        private const val TAG = "Hammer"
        private const val READ_TIMEOUT_MILLIS = 10_000

        fun socketName(applicationId: String) = "hammer_$applicationId"
    }
}
