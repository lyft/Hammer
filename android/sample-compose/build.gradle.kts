plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
}

android {
    namespace = "com.example.hammer.compose"
    compileSdk = 37

    defaultConfig {
        applicationId = "com.example.hammer.compose"
        minSdk = 28
        targetSdk = 37
        versionCode = 1
        versionName = "1.0"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        // A build that has the agent but isn't debuggable, so e2e.sh can check that the agent refuses to start
        create("nonDebuggable") {
            initWith(getByName("debug"))
            isDebuggable = false
            matchingFallbacks += "release"
        }
    }

    buildFeatures {
        compose = true
    }
}

kotlin {
    jvmToolchain(17)
}

dependencies {
    implementation(platform(libs.compose.bom))
    implementation(libs.androidx.activity.compose)
    implementation(libs.compose.material3)

    // The one line an app adds; the agent starts on its own in debug builds
    debugImplementation(project(":hammer-agent"))
    "nonDebuggableImplementation"(project(":hammer-agent"))

    androidTestImplementation(project(":test-client"))
    androidTestImplementation(libs.androidx.test.core)
    androidTestImplementation(libs.androidx.test.ext.junit)
    androidTestImplementation(libs.androidx.test.runner)
    androidTestImplementation(libs.assertj)
}
