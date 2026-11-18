package com.lyft.hammer.agent.testing

import android.net.LocalSocket
import android.net.LocalSocketAddress
import org.json.JSONArray
import org.json.JSONObject

/** Sends requests to the agent of the app [packageName], from inside that app's process, as `hammer` does through adb. */
class AgentClient(private val packageName: String) {

    class Response(val status: Int, val body: String) {
        val json: JSONObject
            get() = JSONObject(body)
    }

    fun commands(): JSONArray = JSONArray(request("GET", "/commands", null).body)

    fun run(name: String, arguments: JSONObject = JSONObject()): Response = request("POST", "/commands/$name", arguments.toString())

    /** Runs [name] and returns its output's text, failing on an error response. */
    fun runOk(name: String, arguments: JSONObject = JSONObject()): String {
        val response = run(name, arguments)
        check(response.status == OK) { "$name failed with ${response.status}: ${response.body}" }
        return response.body
    }

    fun describe(): JSONArray = JSONArray(runOk("describe"))

    /** The first element of `describe`'s tree that [matches], depth first, or null. */
    fun element(matches: (JSONObject) -> Boolean): JSONObject? = find(describe(), matches)

    private fun find(nodes: JSONArray, matches: (JSONObject) -> Boolean): JSONObject? {
        for (index in 0 until nodes.length()) {
            val node = nodes.getJSONObject(index)
            if (matches(node)) return node
            node.optJSONArray("children")?.let { children -> find(children, matches)?.let { return it } }
        }
        return null
    }

    private fun request(method: String, path: String, body: String?): Response {
        LocalSocket().use { socket ->
            socket.connect(LocalSocketAddress("hammer_$packageName", LocalSocketAddress.Namespace.ABSTRACT))
            val bytes = body?.toByteArray().orEmpty()
            val head = buildString {
                append("$method $path HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n")
                if (body != null) append("Content-Type: application/json\r\n")
                append("Content-Length: ${bytes.size}\r\n\r\n")
            }
            socket.outputStream.write(head.toByteArray() + bytes)
            socket.outputStream.flush()
            val response = socket.inputStream.readBytes().decodeToString()
            val status = response.substringAfter(' ').substringBefore(' ').toInt()
            return Response(status, response.substringAfter("\r\n\r\n"))
        }
    }

    private fun ByteArray?.orEmpty() = this ?: ByteArray(0)

    private companion object {
        const val OK = 200
    }
}

/** A JSON object of [entries], such as `arguments("identifier" to "greet_button")`. */
fun arguments(vararg entries: Pair<String, Any>): JSONObject = JSONObject().apply {
    entries.forEach { (key, value) -> put(key, if (value is List<*>) JSONArray(value) else value) }
}
