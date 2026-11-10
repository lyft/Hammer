package com.lyft.hammer.agent.ui

/**
 * Whether the app has Compose UI, which the library only compiles against. Checking it loads no
 * Compose class, so View-only apps run without Compose.
 */
internal object ComposeSupport {
    val isAvailable: Boolean by lazy {
        try {
            Class.forName("androidx.compose.ui.node.RootForTest", false, ComposeSupport::class.java.classLoader)
            true
        } catch (exception: ClassNotFoundException) {
            false
        }
    }
}
