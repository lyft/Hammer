package com.lyft.hammer.agent

import org.assertj.core.api.Assertions.assertThat
import org.junit.Test

class RequestRulesTest {

    @Test
    fun isAllowedPeer_shellRootOrSelf_allowsThem() {
        assertThat(listOf(2000, 0, 10123).map { RequestRules.isAllowedPeer(it, ownUid = 10123) })
            .containsExactly(true, true, true)
    }

    @Test
    fun isAllowedPeer_otherApp_rejectsIt() {
        assertThat(RequestRules.isAllowedPeer(10456, ownUid = 10123)).isFalse()
    }

    @Test
    fun peerRejection_otherApp_isForbidden() {
        val response = RequestRules.peerRejection(10456)

        assertThat(response.status).isEqualTo(403)
        assertThat(response.body).isEqualTo(
            """{"error":"Connections from uid 10456 are not allowed","code":"invalid_request",""" +
                """"hint":"Connect through adb forward, such as with the hammer command line tool"}""",
        )
    }

    @Test
    fun rejection_toolRequest_allowsIt() {
        assertThat(RequestRules.rejection(post(mapOf("host" to "127.0.0.1:51234", "content-type" to "application/json; charset=utf-8"))))
            .isNull()
    }

    @Test
    fun rejection_getWithoutContentType_allowsIt() {
        assertThat(RequestRules.rejection(request("GET", mapOf("host" to "localhost:9876")))).isNull()
    }

    @Test
    fun rejection_ipv6Host_allowsIt() {
        assertThat(RequestRules.rejection(post(mapOf("host" to "[::1]:9876", "content-type" to "application/json")))).isNull()
    }

    @Test
    fun rejection_origin_isForbidden() {
        val response = RequestRules.rejection(post(mapOf("origin" to "https://example.com", "content-type" to "application/json")))

        assertThat(response?.status).isEqualTo(403)
        assertThat(response?.body).contains("\"error\":\"Requests from web browsers are not allowed\"")
    }

    @Test
    fun rejection_secFetchSite_isForbidden() {
        val response = RequestRules.rejection(post(mapOf("sec-fetch-site" to "cross-site", "content-type" to "application/json")))

        assertThat(response?.status).isEqualTo(403)
    }

    @Test
    fun rejection_domainHost_isForbidden() {
        val response = RequestRules.rejection(post(mapOf("host" to "evil.example:9876", "content-type" to "application/json")))

        assertThat(response?.status).isEqualTo(403)
        assertThat(response?.body).contains("\"error\":\"Requests for host evil.example:9876 are not allowed\"")
    }

    @Test
    fun rejection_outOfRangeIpv4_isForbidden() {
        assertThat(RequestRules.rejection(post(mapOf("host" to "256.0.0.1", "content-type" to "application/json")))?.status).isEqualTo(403)
    }

    @Test
    fun rejection_postWithFormContentType_isUnsupported() {
        val response = RequestRules.rejection(post(mapOf("content-type" to "text/plain")))

        assertThat(response?.status).isEqualTo(415)
        assertThat(response?.body).contains("\"code\":\"invalid_request\"")
    }

    private fun post(headers: Map<String, String>) = request("POST", headers)

    private fun request(method: String, headers: Map<String, String>) = HttpRequest(method, "/commands/tap", headers, ByteArray(0))
}
