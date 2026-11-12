package com.lyft.hammer.agent

import android.net.LocalServerSocket
import android.net.LocalSocket
import android.os.Process
import android.system.ErrnoException
import android.system.Os
import android.system.OsConstants
import android.system.StructPollfd
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import java.io.IOException

/**
 * Listens on the abstract socket [socketName] and answers each connection with [handler]. One socket
 * per app lets several apps with an agent run side by side.
 *
 * @throws IOException if another process holds the socket.
 */
internal class SocketListener(
    private val socketName: String,
    private val handler: ConnectionHandler,
    private val log: AgentLog,
) : AgentListener {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val server = LocalServerSocket(socketName)

    @Volatile
    private var closed = false

    init {
        scope.launch { accept() }
    }

    override fun close() {
        closed = true
        // Closing alone doesn't wake a thread blocked in accept()
        try {
            Os.shutdown(server.fileDescriptor, OsConstants.SHUT_RDWR)
        } catch (exception: ErrnoException) {
            log.warning("Hammer agent couldn't shut down @$socketName", exception)
        }
        server.close()
        scope.cancel()
    }

    private fun accept() {
        try {
            while (true) {
                val socket = server.accept()
                scope.launch { serve(socket) }
            }
        } catch (exception: IOException) {
            if (!closed) log.error("Hammer agent stopped; restart the app to restore it", exception)
        }
    }

    private suspend fun serve(socket: LocalSocket) {
        socket.use {
            try {
                socket.soTimeout = READ_TIMEOUT_MILLIS
                handler.respond(socket.inputStream, socket.outputStream, socket.peerCredentials.uid, Process.myUid()) {
                    isClosedByClient(socket)
                }
            } catch (exception: IOException) {
                log.warning("Hammer agent connection failed", exception)
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
        private const val READ_TIMEOUT_MILLIS = 10_000

        fun socketName(applicationId: String) = "hammer_$applicationId"
    }
}
