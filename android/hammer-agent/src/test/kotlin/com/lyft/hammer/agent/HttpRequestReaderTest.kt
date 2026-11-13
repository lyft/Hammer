package com.lyft.hammer.agent

import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.catchThrowableOfType
import org.junit.Test

class HttpRequestReaderTest {

    @Test
    fun read_postWithBody_parsesRequestLineHeadersAndBody() {
        val request = read("POST /commands/tap HTTP/1.1\r\nHost: 127.0.0.1:9876\r\nContent-Length: 7\r\nX-Note:  a:b \r\n\r\n{\"a\":1}")

        assertThat(request.method).isEqualTo("POST")
        assertThat(request.path).isEqualTo("/commands/tap")
        assertThat(request.headers).isEqualTo(mapOf("host" to "127.0.0.1:9876", "content-length" to "7", "x-note" to "a:b"))
        assertThat(request.body.decodeToString()).isEqualTo("{\"a\":1}")
    }

    @Test
    fun read_bodyLongerThanContentLength_keepsContentLengthBytes() {
        val request = read("POST / HTTP/1.1\r\nContent-Length: 2\r\n\r\nabcdef")

        assertThat(request.body.decodeToString()).isEqualTo("ab")
    }

    @Test
    fun read_noContentLength_hasEmptyBody() {
        val request = read("GET /commands HTTP/1.1\r\n\r\nignored")

        assertThat(request.body).isEmpty()
    }

    @Test
    fun read_headWithoutSeparator_isIncompleteHead() {
        assertThat(error("GET /commands HTTP/1.1\r\n").message).isEqualTo("Incomplete request head")
    }

    @Test
    fun read_headOverLimit_isIncompleteHead() {
        assertThat(error("GET /commands HTTP/1.1\r\nX: 1234567890\r\n\r\n", limit = 16).message).isEqualTo("Incomplete request head")
    }

    @Test
    fun read_requestLineWithoutVersion_isInvalid() {
        assertThat(error("GET /commands\r\n\r\n").message).isEqualTo("Invalid request line")
    }

    @Test
    fun read_contentLengthOverLimit_isTooLarge() {
        assertThat(error("POST / HTTP/1.1\r\nContent-Length: 1000\r\n\r\n", limit = 100).message).isEqualTo("Request body is too large")
    }

    @Test
    fun read_contentLengthNotANonNegativeNumber_isInvalid() {
        listOf("-1", "abc", "99999999999", "1.5", "").forEach { length ->
            assertThat(error("POST / HTTP/1.1\r\nContent-Length: $length\r\n\r\n{}").message)
                .`as`(length)
                .isEqualTo("Invalid Content-Length")
        }
    }

    @Test
    fun read_bodyShorterThanContentLength_isIncompleteBody() {
        assertThat(error("POST / HTTP/1.1\r\nContent-Length: 10\r\n\r\nabc").message).isEqualTo("Incomplete request body")
    }

    @Test
    fun read_carriageReturnsBeforeSeparator_findsSeparator() {
        val request = read("GET /commands HTTP/1.1\r\r\n\r\n")

        assertThat(request.path).isEqualTo("/commands")
    }

    private fun read(raw: String) = HttpRequestReader.read(raw.byteInputStream())

    private fun error(raw: String, limit: Int = HttpRequestReader.MAX_REQUEST_BYTES): InvalidHttpRequestException =
        catchThrowableOfType({ HttpRequestReader.read(raw.byteInputStream(), limit) }, InvalidHttpRequestException::class.java)
}
