package com.lyft.hammer.agent

import java.io.ByteArrayOutputStream
import java.io.InputStream

internal class InvalidHttpRequestException(message: String) : Exception(message)

/** Reads one HTTP/1.1 request, with the same limits and messages as Hammer's `receiveRequest(limit:)`. */
internal object HttpRequestReader {

    const val MAX_REQUEST_BYTES = 16 shl 20

    private val HEAD_SEPARATOR = "\r\n\r\n".toByteArray()
    private const val REQUEST_LINE_PARTS = 3

    fun read(input: InputStream, limit: Int = MAX_REQUEST_BYTES): HttpRequest {
        val buffered = input.buffered()
        val head = readHead(buffered, limit)
        val lines = head.split("\r\n")
        val requestLine = lines.first().split(" ").filter { it.isNotEmpty() }
        if (requestLine.size != REQUEST_LINE_PARTS) throw InvalidHttpRequestException("Invalid request line")

        val headers = lines.drop(1).mapNotNull { line ->
            val separator = line.indexOf(':')
            if (separator < 0) null else line.substring(0, separator).lowercase() to line.substring(separator + 1).trim()
        }.toMap()

        val contentLength = headers["content-length"]?.let { value ->
            value.toIntOrNull()?.takeIf { it >= 0 } ?: throw InvalidHttpRequestException("Invalid Content-Length")
        } ?: 0
        if (contentLength > limit) throw InvalidHttpRequestException("Request body is too large")

        return HttpRequest(
            method = requestLine[0],
            path = requestLine[1],
            headers = headers,
            body = readBody(buffered, contentLength),
        )
    }

    private fun readHead(input: InputStream, limit: Int): String {
        val head = ByteArrayOutputStream()
        var matched = 0
        while (matched < HEAD_SEPARATOR.size) {
            if (head.size() >= limit) throw InvalidHttpRequestException("Incomplete request head")
            val next = input.read()
            if (next == -1) throw InvalidHttpRequestException("Incomplete request head")
            head.write(next)
            matched = when (next.toByte()) {
                HEAD_SEPARATOR[matched] -> matched + 1
                HEAD_SEPARATOR[0] -> 1
                else -> 0
            }
        }
        return String(head.toByteArray(), 0, head.size() - HEAD_SEPARATOR.size, Charsets.UTF_8)
    }

    private fun readBody(input: InputStream, contentLength: Int): ByteArray {
        val body = ByteArray(contentLength)
        var offset = 0
        while (offset < contentLength) {
            val read = input.read(body, offset, contentLength - offset)
            if (read == -1) throw InvalidHttpRequestException("Incomplete request body")
            offset += read
        }
        return body
    }
}
