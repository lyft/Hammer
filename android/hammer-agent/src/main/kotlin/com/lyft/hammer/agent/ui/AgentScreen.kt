package com.lyft.hammer.agent.ui

import android.app.Application
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/** The screen state built-in commands share: windows, refs and the ways to act on them. */
internal class AgentScreen(application: Application) {

    val activities = ForegroundActivities(application)
    val references = References()
    private val reader = ScreenReader(activities)
    private val main = Dispatchers.Main

    val injector = EventInjector(reader, activities, main)
    val idle = IdleWaiter(reader, main)
    val screenshots = Screenshots(reader, activities, main, Dispatchers.Default)

    suspend fun snapshot(): Snapshot = withContext(main) { reader.read() }.also { references.assign(it.roots) }

    /** The snapshot, or null while the app has no window in the foreground. */
    suspend fun snapshotOrNull(): Snapshot? =
        withContext(main) { reader.readOrNull() }?.also { references.assign(it.roots) }
}
