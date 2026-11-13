package com.lyft.hammer.agent.ui

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.graphics.Rect
import android.os.Build
import android.view.View
import android.view.WindowManager
import android.view.inspector.WindowInspector
import com.lyft.hammer.agent.AgentError
import com.lyft.hammer.agent.AgentErrorCode

/** Reads the app's foreground windows into a [Snapshot]. Every method runs on the main thread. */
internal class ScreenReader(private val activities: ForegroundActivities) {

    /** The roots of the app's shown windows, back to front, such as an activity and its dialogs. */
    fun windowRoots(): List<View> {
        val roots = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            WindowInspector.getGlobalWindowViews()
        } else {
            listOfNotNull(activities.resumedActivity?.window?.decorView)
        }
        return roots.filter {
            it.isAttachedToWindow && it.windowVisibility == View.VISIBLE && it.isShown && it.width > 0 && !isLeaving(it)
        }
    }

    // A finished activity's windows, and its dialogs, stay attached and visible until its exit animation ends
    private fun isLeaving(root: View): Boolean {
        val activity = activities.activity(root) ?: root.context.activity()
        return activity != null && (activity.isFinishing || activity.isDestroyed)
    }

    private tailrec fun Context.activity(): Activity? = when (this) {
        is Activity -> this
        is ContextWrapper -> baseContext?.activity()
        else -> null
    }

    fun read(): Snapshot = readOrNull() ?: throw AgentError(
        "The app has no window in the foreground",
        AgentErrorCode.NOT_READY,
        "Bring the app to the foreground, or wait_for_idle if it is still launching",
    )

    /** The snapshot, or null while the app has no window in the foreground, such as while it launches. */
    fun readOrNull(): Snapshot? {
        val roots = windowRoots()
        if (roots.isEmpty()) return null
        val density = roots.first().resources.displayMetrics.density.toDouble()
        val reader = ViewElements(density)
        val windows = roots.map { reader.window(it, screenBounds(it)) }
        return Snapshot(windows, windows.last().frame, density, touches(roots, density))
    }

    companion object {
        /** How each of the windows of [roots] takes touches, with frames in dp. */
        fun touches(roots: List<View>, density: Double): List<WindowTouch> = roots.map { root ->
            val flags = (root.layoutParams as? WindowManager.LayoutParams)?.flags ?: 0
            WindowTouch(
                frame = screenBounds(root).toFrame(density),
                touchable = flags and WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE == 0,
                modal = flags and WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL == 0,
            )
        }

        fun screenBounds(view: View): Rect {
            val location = IntArray(2).also(view::getLocationOnScreen)
            return Rect(location[0], location[1], location[0] + view.width, location[1] + view.height)
        }
    }
}
