plugins {
    alias(libs.plugins.android.library)
}

android {
    namespace = "com.lyft.hammer.agent"
    compileSdk = 37

    defaultConfig {
        minSdk = 28
    }
}

kotlin {
    jvmToolchain(17)
}

dependencies {
    implementation(libs.androidx.activity)
    implementation(libs.androidx.core)
    implementation(libs.compose.ui)
    implementation(libs.gson)
    implementation(libs.kotlinx.coroutines.android)

    testImplementation(libs.junit)
    testImplementation(libs.assertj)
    testImplementation(libs.kotlinx.coroutines.test)
}
