pluginManagement {
    // Keep Flutter's includeBuild so flutter_tools stays wired
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val path = properties.getProperty("flutter.sdk")
        require(path != null) { "flutter.sdk not set in local.properties" }
        path
    }
    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }

    // Force tool versions used by the plugins {} DSL
    plugins {
        id("dev.flutter.flutter-plugin-loader") version "1.0.0"
        id("com.android.application") version "8.9.1" apply false
        id("com.android.library")    version "8.9.1" apply false
        // KGP version updated to 2.1.0 to resolve previous warning
        id("org.jetbrains.kotlin.android") version "2.1.0" apply false 
    }

    // Extra safety: map any android plugin request to AGP 8.9.1
    resolutionStrategy {
        eachPlugin {
            if (requested.id.id == "com.android.application" || requested.id.id == "com.android.library") {
                useModule("com.android.tools.build:gradle:8.9.1")
            }
        }
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_PROJECT)
    repositories {
        google()
        mavenCentral()
    }
}

// -------------------------------------------------------------------------
// FIX: Include the Flutter project and plugins (Resolves 'Unresolved reference')
// -------------------------------------------------------------------------

// Check if the auto-generated Flutter plugins file exists and apply it.
// This is the idiomatic Kotlin DSL way to load external settings files.
val flutterPluginsFile = File(settingsDir.parentFile, "/.flutter-plugins")
if (flutterPluginsFile.exists()) {
    apply(from = flutterPluginsFile)
}

include(":app")