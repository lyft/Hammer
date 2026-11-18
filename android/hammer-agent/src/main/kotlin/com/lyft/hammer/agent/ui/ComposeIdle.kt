package com.lyft.hammer.agent.ui

import android.view.View
import androidx.compose.runtime.Recomposer
import androidx.compose.ui.platform.findViewTreeCompositionContext

/** Names Compose types, so call it only when [OptionalLibraries.hasCompose]. */
internal object ComposeIdle {
    /** Whether the Compose content in the window of [root] has recompositions or effects still to run. */
    fun hasPendingWork(root: View): Boolean = (root.findViewTreeCompositionContext() as? Recomposer)?.hasPendingWork == true
}
