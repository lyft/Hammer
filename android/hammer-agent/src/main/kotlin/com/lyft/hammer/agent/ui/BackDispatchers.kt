package com.lyft.hammer.agent.ui

import android.view.View
import androidx.activity.findViewTreeOnBackPressedDispatcherOwner

/** The only class that names `androidx.activity` types, so call it only when [OptionalLibraries.hasActivity]. */
internal object BackDispatchers {
    /** Goes back with the `OnBackPressedDispatcher` of [window], such as a Compose dialog's, when it has one. */
    fun pressBack(window: View): Boolean {
        val dispatcher = window.findViewTreeOnBackPressedDispatcherOwner()?.onBackPressedDispatcher ?: return false
        dispatcher.onBackPressed()
        return true
    }
}
