// Top-level build file where you can add configuration options common to all sub-projects/modules.

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Android Gradle Plugin (match with Gradle 8.7 wrapper)
        classpath("com.android.tools.build:gradle:8.4.2")

        // Kotlin Gradle Plugin (keep in sync with AGP)
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.24")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Repoint the top-level build output to ../../build (kept from your snippet)
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// Ensure :app is evaluated first for dependent module configs (kept from your snippet)
subprojects {
    project.evaluationDependsOn(":app")
}

// Clean task (kept from your snippet)
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
