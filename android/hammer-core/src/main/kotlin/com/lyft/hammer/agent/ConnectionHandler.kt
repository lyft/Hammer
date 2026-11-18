package com.lyft.hammer.agent

import java.io.InputStream
import java.io.OutputStream

/**
 * Answers the single request of one connection.
 *
 * With a [proofKey], each response to a request with a [ProofOfKey.CHALLENGE_HEADER] carries the challenge's
 * HMAC under [ProofOfKey.PROOF_HEADER], so the client can tell this server from another process that took its
 * socket name first. Abstract sockets are open to every app, so the client checks it before sending anything.
 */
internal class ConnectionHandler(private val router: CommandRouter, private val proofKey: ByteArray? = null) {

    /**
     * Answers the request, or drops it when [isClientGone] says the client closed the connection before it ran, such
     * as hammer giving up while Android froze the app or while the request waited for another command. Running it then
     * would act after the caller moved on.
     */
    suspend fun respond(input: InputStream, output: OutputStream, peerUid: Int, ownUid: Int, isClientGone: () -> Boolean) {
        val response = response(input, peerUid, ownUid, isClientGone) ?: return
        output.write(response.serialized())
        output.flush()
    }

    private suspend fun response(input: InputStream, peerUid: Int, ownUid: Int, isClientGone: () -> Boolean): HttpResponse? {
        if (!RequestRules.isAllowedPeer(peerUid, ownUid)) return RequestRules.peerRejection(peerUid)
        val request = try {
            HttpRequestReader.read(input)
        } catch (exception: InvalidHttpRequestException) {
            return HttpResponse.error(HttpResponse.BAD_REQUEST, AgentErrorCode.INVALID_REQUEST, exception.message.orEmpty())
        }
        val response = RequestRules.rejection(request) ?: router.respond(request, isClientGone) ?: return null
        val challenge = request.headers[ProofOfKey.CHALLENGE_HEADER]
        return if (proofKey != null && challenge != null) {
            response.withHeader(ProofOfKey.PROOF_HEADER, ProofOfKey.proof(proofKey, challenge))
        } else {
            response
        }
    }
}
