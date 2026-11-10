package com.lyft.hammer.agent

import com.lyft.hammer.agent.core.AgentErrorCode
import java.io.InputStream
import java.io.OutputStream

/** Answers the single request of one connection. */
internal class ConnectionHandler(private val router: CommandRouter) {

    /**
     * Answers the request, or drops it when [isClientGone] says the client closed the connection before it ran, such
     * as hammer giving up while Android froze the app. Running it then would act after the caller moved on.
     */
    suspend fun respond(input: InputStream, output: OutputStream, peerUid: Int, ownUid: Int, isClientGone: () -> Boolean) {
        val response = response(input, peerUid, ownUid, isClientGone) ?: return
        output.write(response.serialized())
        output.flush()
    }

    private suspend fun response(input: InputStream, peerUid: Int, ownUid: Int, isClientGone: () -> Boolean): HttpResponse? {
        if (!RequestRules.isAllowedPeer(peerUid, ownUid)) return RequestRules.peerRejection(peerUid)
        return try {
            val request = HttpRequestReader.read(input)
            RequestRules.rejection(request) ?: if (isClientGone()) null else router.respond(request)
        } catch (exception: InvalidHttpRequestException) {
            HttpResponse.error(HttpResponse.BAD_REQUEST, AgentErrorCode.INVALID_REQUEST, exception.message.orEmpty())
        }
    }
}
