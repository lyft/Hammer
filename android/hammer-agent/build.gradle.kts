plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.maven.publish)
}

android {
    namespace = "com.lyft.hammer.agent"
    compileSdk = 37

    defaultConfig {
        minSdk = 28
        consumerProguardFiles("consumer-rules.pro")
    }
}

kotlin {
    jvmToolchain(17)
    explicitApi()
    // Apps on older Kotlin versions can use the library, which doesn't need newer language features
    coreLibrariesVersion = "2.1.21"
    compilerOptions {
        apiVersion = org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_2_1
        languageVersion = org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_2_1
        // Interface methods with a body stay default methods, which the API dump records
        jvmDefault = org.jetbrains.kotlin.gradle.dsl.JvmDefaultMode.ENABLE
    }

    @OptIn(org.jetbrains.kotlin.gradle.dsl.abi.ExperimentalAbiValidation::class)
    abiValidation()
}

dependencies {
    implementation(libs.androidx.activity)
    implementation(libs.androidx.core)
    // Optional: the agent reads Compose semantics only when the app has Compose UI
    compileOnly(libs.compose.ui)
    implementation(libs.gson)
    implementation(libs.kotlinx.coroutines.android)

    testImplementation(libs.junit)
    testImplementation(libs.assertj)
    testImplementation(libs.kotlinx.coroutines.test)
}

// Release.yml passes the Hammer release tag as VERSION_NAME
mavenPublishing {
    coordinates("com.lyft.hammer", "hammer-agent-android", providers.gradleProperty("VERSION_NAME").getOrElse("0.0.0-SNAPSHOT"))
    publishToMavenCentral()
    // Only releases have a key, so publishToMavenLocal works without one
    if (providers.gradleProperty("signingInMemoryKey").isPresent) {
        signAllPublications()
    }

    pom {
        name = "Hammer agent for Android"
        description = "Lets the hammer tool and MCP server describe and drive a debug build of an Android app."
        url = "https://github.com/lyft/Hammer"
        licenses {
            license {
                name = "The Apache License, Version 2.0"
                url = "https://www.apache.org/licenses/LICENSE-2.0.txt"
                distribution = "repo"
            }
        }
        developers {
            developer {
                id = "lyft"
                name = "Lyft"
                url = "https://github.com/lyft"
            }
        }
        scm {
            url = "https://github.com/lyft/Hammer"
            connection = "scm:git:https://github.com/lyft/Hammer.git"
            developerConnection = "scm:git:ssh://git@github.com/lyft/Hammer.git"
        }
    }
}
