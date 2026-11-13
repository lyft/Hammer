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

    /**
     * Espresso's registry of idling resources, which apps fill to tell tests they are busy. Read by
     * reflection, so the agent doesn't depend on Espresso. Null without it.
     */
    val idlingRegistry: Class<*>? by lazy {
        try {
            Class.forName("androidx.test.espresso.IdlingRegistry", true, OptionalLibraries::class.java.classLoader)
        } catch (exception: ClassNotFoundException) {
            null
        }
    }

    private fun isPresent(className: String): Boolean = try {
        Class.forName(className, false, OptionalLibraries::class.java.classLoader)
        true
    } catch (exception: ClassNotFoundException) {
        false
    }
}
