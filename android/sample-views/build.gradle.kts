plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
}

// An app with Views only, to show the agent runs without Compose on the classpath
android {
    namespace = "com.example.hammer.views"
    compileSdk = 37

    defaultConfig {
        applicationId = "com.example.hammer.views"
        minSdk = 28
        targetSdk = 37
        versionCode = 1
        versionName = "1.0"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }
}

kotlin {
    jvmToolchain(17)
}

dependencies {
    implementation(libs.androidx.activity)

    debugImplementation(project(":hammer-agent"))

    androidTestImplementation(project(":test-client"))
    androidTestImplementation(libs.androidx.test.core)
    androidTestImplementation(libs.androidx.test.ext.junit)
    androidTestImplementation(libs.androidx.test.runner)
    androidTestImplementation(libs.assertj)
}
