package com.lyft.hammer.agent

import com.lyft.hammer.agent.core.AgentErrorCode

/**
 * Hammer's request rules. A browser on the host can reach the agent through the `adb forward` port,
 * so requests that browsers send are refused, as Hammer's server does.
 */
internal object RequestRules {

    private const val SHELL_UID = 2000
    private const val ROOT_UID = 0

    /**
     * Abstract sockets are open to every app on the device, so only adb (`shell`), root and the app
     * itself may connect. This stands in for Hammer's loopback-only default.
     */
    fun isAllowedPeer(peerUid: Int, ownUid: Int): Boolean = peerUid == SHELL_UID || peerUid == ROOT_UID || peerUid == ownUid

    fun peerRejection(peerUid: Int): HttpResponse = HttpResponse.error(
        HttpResponse.FORBIDDEN,
        AgentErrorCode.INVALID_REQUEST,
        "Connections from uid $peerUid are not allowed",
        "Connect through adb forward, such as with the hammer command line tool",
    )

    fun rejection(request: HttpRequest): HttpResponse? {
        if ("origin" in request.headers || "sec-fetch-site" in request.headers) {
            return HttpResponse.error(
                HttpResponse.FORBIDDEN,
                AgentErrorCode.INVALID_REQUEST,
                "Requests from web browsers are not allowed",
                "Use the hammer command line tool, or a client that is not a browser",
            )
        }

        // A domain name means a site may have resolved its own domain to the forwarded port.
        val host = request.headers["host"]
        if (host != null && !isAddress(host)) {
            return HttpResponse.error(
                HttpResponse.FORBIDDEN,
                AgentErrorCode.INVALID_REQUEST,
                "Requests for host $host are not allowed",
                "Connect with an IP address such as 127.0.0.1, or localhost",
            )
        }

        // Browsers only send JSON after a preflight request, which the server never allows.
        val contentType = request.headers["content-type"]?.substringBefore(';')?.trim()?.lowercase()
        if (request.method == "POST" && contentType != "application/json") {
            return HttpResponse.error(
                HttpResponse.UNSUPPORTED_MEDIA_TYPE,
                AgentErrorCode.INVALID_REQUEST,
                "Requests must have the content type application/json",
                "Send the header Content-Type: application/json",
            )
        }

        return null
    }

    private val IPV4 = Regex("""(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}""")
    private val IPV6 = Regex("""[0-9A-Fa-f:.]*:[0-9A-Fa-f:.]*""")

    private fun isAddress(host: String): Boolean {
        if (host.startsWith("[")) return IPV6.matches(host.drop(1).substringBefore(']'))
        val name = host.substringBefore(':')
        return name == "localhost" || IPV4.matches(name)
    }
}
