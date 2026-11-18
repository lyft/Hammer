package com.lyft.hammer.agent

import android.app.Application
import android.content.ContentProvider
import android.content.ContentValues
import android.database.Cursor
import android.net.Uri

/** Starts an agent when the app launches, as the library's manifest declares, unless the app turns it off. */
internal class HammerAgentProvider : ContentProvider() {

    override fun onCreate(): Boolean {
        val application = context?.applicationContext as? Application ?: return true
        // Auto-start must never take the app down, whatever goes wrong
        try {
            agent = AutoStart.run(AndroidEnvironment(application), AgentLog.Logcat)
        } catch (exception: Exception) {
            AgentLog.Logcat.error("Hammer agent didn't start", exception)
        } catch (error: LinkageError) {
            AgentLog.Logcat.error("Hammer agent didn't start", error)
        }
        return true
    }

    override fun query(uri: Uri, projection: Array<out String>?, selection: String?, selectionArgs: Array<out String>?, sortOrder: String?): Cursor? = null

    override fun getType(uri: Uri): String? = null

    override fun insert(uri: Uri, values: ContentValues?): Uri? = null

    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int = 0

    override fun update(uri: Uri, values: ContentValues?, selection: String?, selectionArgs: Array<out String>?): Int = 0

    private companion object {
        // Keeps the auto-started agent for the life of the process
        var agent: AgentCore? = null
    }
}

/** What the library's provider does when the app launches. */
internal object AutoStart {
    /** The `<meta-data>` that turns auto-start off with the value `false`. */
    const val ENABLED_KEY = "com.lyft.hammer.agent.autostart"

    /** @return the started agent, or null when it didn't start, having logged why. */
    fun run(environment: AgentEnvironment, log: AgentLog): AgentCore? {
        if (environment.manifestEntries[ENABLED_KEY] == "false") {
            log.info("Hammer agent auto-start is off in the app's manifest")
            return null
        }
        if (!environment.isDebuggable) {
            log.warning("Hammer agent didn't start; the app isn't debuggable, and auto-start runs only in debuggable builds")
            return null
        }
        val core = AgentCore(environment, log, readsManifestRegistrars = true)
        return try {
            if (core.start(allowsReleaseBuild = false)) core else null
        } catch (error: AgentStartError) {
            log.error(error.message.orEmpty())
            null
        }
    }
}
