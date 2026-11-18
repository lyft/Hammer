package com.lyft.hammer.agent

import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec

/** Proves a server holds a key without sending it: the HMAC-SHA256 of the client's challenge, in hex. */
internal object ProofOfKey {
    /** The request header with the client's challenge, lowercased as [HttpRequest.headers] keeps names. */
    const val CHALLENGE_HEADER = "x-hammer-challenge"

    const val PROOF_HEADER = "X-Hammer-Proof"

    fun proof(key: ByteArray, challenge: String): String {
        val mac = Mac.getInstance(ALGORITHM).apply { init(SecretKeySpec(key, ALGORITHM)) }
        return mac.doFinal(challenge.toByteArray(Charsets.UTF_8)).joinToString("") { "%02x".format(it) }
    }

    private const val ALGORITHM = "HmacSHA256"
}
