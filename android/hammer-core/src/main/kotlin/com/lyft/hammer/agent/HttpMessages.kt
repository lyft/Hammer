package com.lyft.hammer.agent

import com.lyft.hammer.agent.core.AgentErrorBody
import com.lyft.hammer.agent.core.Json

internal class HttpRequest(
    val method: String,
    val path: String,
    /** By lowercased name. */
    val headers: Map<String, String>,
    val body: ByteArray,
)

internal class HttpResponse(val status: Int, val body: String, val headers: Map<String, String> = emptyMap()) {

    fun withHeader(name: String, value: String) = HttpResponse(status, body, headers + (name to value))

    fun serialized(): ByteArray {
        val bytes = body.toByteArray()
        val head = "HTTP/1.1 $status ${reasonPhrase(status)}\r\n" +
            headers.entries.joinToString("") { (name, value) -> "$name: $value\r\n" } +
            "Content-Type: application/json\r\n" +
            "Content-Length: ${bytes.size}\r\n" +
            "Connection: close\r\n\r\n"
        return head.toByteArray() + bytes
    }

    companion object {
        const val OK = 200
        const val BAD_REQUEST = 400
        const val FORBIDDEN = 403
        const val NOT_FOUND = 404
        const val UNSUPPORTED_MEDIA_TYPE = 415
        const val INTERNAL_SERVER_ERROR = 500

        fun json(status: Int, body: JsonValue) = HttpResponse(status, Json.encode(body))

        fun error(status: Int, code: String, error: String, hint: String? = null) =
            json(status, AgentErrorBody(error = error, code = code, hint = hint).toJson())

        private fun reasonPhrase(status: Int) = when (status) {
            OK -> "OK"
            BAD_REQUEST -> "Bad Request"
            FORBIDDEN -> "Forbidden"
            NOT_FOUND -> "Not Found"
            UNSUPPORTED_MEDIA_TYPE -> "Unsupported Media Type"
            else -> "Internal Server Error"
        }
    }
}
