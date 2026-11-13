plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.kotlin.android)
    `maven-publish`
}

android {
    namespace = "com.lyft.hammer.agent"
    compileSdk = 37

    defaultConfig {
        minSdk = 28
        consumerProguardFiles("consumer-rules.pro")
        // AGP otherwise requires apps to compile with this library's compileSdk; sample-views checks 34
        aarMetadata {
            minCompileSdk = 34
        }
    }

    publishing {
        singleVariant("release")
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
    // Optional: used only when the app has them, see OptionalLibraries
    compileOnly(libs.agent.activity)
    compileOnly(libs.agent.compose.ui)
    implementation(libs.agent.coroutines.android)

    testImplementation(libs.junit)
    testImplementation(libs.assertj)
    testImplementation(libs.agent.coroutines.test)
}

// Release.yml passes the Hammer release tag as VERSION_NAME and attaches the AAR and POM to the release
publishing {
    publications {
        register<MavenPublication>("release") {
            groupId = "com.lyft.hammer"
            artifactId = "hammer-agent-android"
            version = providers.gradleProperty("VERSION_NAME").getOrElse("0.0.0-SNAPSHOT")
            afterEvaluate {
                from(components["release"])
            }

            pom {
                name = "Hammer agent for Android"
                description = "Lets the hammer tool and MCP server describe and drive a debug build of an Android app."
                url = "https://github.com/lyft/Hammer"
                licenses {
                    license {
                        name = "The Apache License, Version 2.0"
                        url = "https://www.apache.org/licenses/LICENSE-2.0.txt"
                    }
                }
            }
        }
    }
    repositories {
        maven {
            name = "release"
            url = uri(layout.buildDirectory.dir("release"))
        }
    }
}

// The release attaches only the AAR and POM, so the POM mustn't point Gradle at a .module file
tasks.withType<GenerateModuleMetadata>().configureEach {
    enabled = false
}
