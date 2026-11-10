package com.lyft.hammer.agent.ui

/**
 * The libraries the agent only compiles against, and uses when the app has them. Checking one loads
 * none of its classes, so apps without it run the agent, and the agent never changes their versions.
 */
internal object OptionalLibraries {
    /** Compose UI, whose semantics [ComposeElements] reads. */
    val hasCompose: Boolean by lazy { isPresent("androidx.compose.ui.node.RootForTest") }

    /** `androidx.activity` 1.5 or later, whose back dispatchers [BackDispatchers] calls. */
    val hasActivity: Boolean by lazy { isPresent("androidx.activity.ViewTreeOnBackPressedDispatcherOwner") }

    private fun isPresent(className: String): Boolean = try {
        Class.forName(className, false, OptionalLibraries::class.java.classLoader)
        true
    } catch (exception: ClassNotFoundException) {
        false
    }
}
