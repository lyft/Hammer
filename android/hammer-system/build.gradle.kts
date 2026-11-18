plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
}

// The system helper: an instrumentation that holds UiAutomation and answers the hammer tool's whole-screen
// commands on the abstract socket hammer_system. The tool embeds its APK and installs it on first use.
android {
    namespace = "com.lyft.hammer.system"
    compileSdk = 37

    defaultConfig {
        applicationId = "com.lyft.hammer.system"
        minSdk = 28
        targetSdk = 37
        versionCode = 1
        versionName = "1"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    sourceSets.getByName("main").java.srcDir("../hammer-core/src/main/kotlin")

    // The tool embeds the release APK, so it is shrunk. It is signed with the build machine's debug key; the
    // tool uninstalls a helper whose APK differs from its own before installing, so any key's build replaces another
    buildTypes {
        release {
            isMinifyEnabled = true
            signingConfig = signingConfigs.getByName("debug")
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"))
        }
    }
}

kotlin {
    jvmToolchain(17)
}

dependencies {
    implementation(libs.agent.coroutines.android)

    testImplementation(libs.junit)
    testImplementation(libs.assertj)
    testImplementation(libs.agent.coroutines.test)

    androidTestImplementation(libs.androidx.test.ext.junit)
    androidTestImplementation(libs.androidx.test.runner)
    androidTestImplementation(libs.assertj)
}
