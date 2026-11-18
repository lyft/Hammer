plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.kotlin.android)
}

// A client of the agent's socket for the samples' instrumentation tests, which run in the app's process
android {
    namespace = "com.lyft.hammer.agent.testing"
    compileSdk = 37

    defaultConfig {
        minSdk = 28
        // sample-views compiles against 34
        aarMetadata {
            minCompileSdk = 34
        }
    }
}

kotlin {
    jvmToolchain(17)
}
