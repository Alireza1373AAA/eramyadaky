pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            val localPropertiesFile = file("local.properties")
            if (localPropertiesFile.exists()) {
                localPropertiesFile.inputStream().use { properties.load(it) }
            }

            val flutterSdkFromProperties = properties.getProperty("flutter.sdk")?.trim()
            val flutterSdkFromEnv = System.getenv("FLUTTER_ROOT")?.trim()
            val resolvedFlutterSdkPath =
                when {
                    !flutterSdkFromProperties.isNullOrEmpty() -> flutterSdkFromProperties
                    !flutterSdkFromEnv.isNullOrEmpty() -> flutterSdkFromEnv
                    else -> null
                }

            require(!resolvedFlutterSdkPath.isNullOrBlank()) {
                """
                Flutter SDK path is missing.
                - Preferred: set flutter.sdk in android/local.properties
                - Alternative: set FLUTTER_ROOT environment variable
                """.trimIndent()
            }

            require(file(resolvedFlutterSdkPath).exists()) {
                "Flutter SDK directory does not exist: $resolvedFlutterSdkPath"
            }

            resolvedFlutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

include(":app")
