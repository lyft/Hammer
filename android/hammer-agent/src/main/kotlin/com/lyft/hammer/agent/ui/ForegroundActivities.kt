package com.lyft.hammer.agent.ui

import android.app.Activity
import android.app.Application
import android.os.Bundle
import android.view.View
import android.view.Window
import java.lang.ref.WeakReference
import java.util.WeakHashMap

/** Tracks the app's activities, to find the resumed one and the window behind a root view. */
internal class ForegroundActivities(application: Application) : Application.ActivityLifecycleCallbacks {

    private val created = WeakHashMap<Activity, Unit>()
    private var resumed: WeakReference<Activity>? = null

    init {
        application.registerActivityLifecycleCallbacks(this)
    }

    val resumedActivity: Activity?
        get() = resumed?.get()

    /** The activity window whose decor view is [root], which PixelCopy can capture. */
    fun window(root: View): Window? = activity(root)?.window

    /** The activity whose window's decor view is [root]. */
    fun activity(root: View): Activity? = created.keys.firstOrNull { it.window?.decorView === root }

    override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) {
        created[activity] = Unit
    }

    override fun onActivityResumed(activity: Activity) {
        resumed = WeakReference(activity)
    }

    override fun onActivityPaused(activity: Activity) {
        if (resumed?.get() === activity) resumed = null
    }

    override fun onActivityDestroyed(activity: Activity) {
        created.remove(activity)
    }

    override fun onActivityStarted(activity: Activity) = Unit

    override fun onActivityStopped(activity: Activity) = Unit

    override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) = Unit
}
