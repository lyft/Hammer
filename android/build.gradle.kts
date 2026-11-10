plugins {
    alias(libs.plugins.android.library) apply false
    // Only puts this Kotlin version on the classpath, which AGP's built-in Kotlin then uses
    alias(libs.plugins.kotlin.android) apply false
}
