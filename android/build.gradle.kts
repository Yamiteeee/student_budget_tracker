// E:\flutterReal\student_budget_tracker\android\build.gradle.kts (REPLACE ENTIRE CONTENT WITH THIS)

plugins {
    // These are the essential plugins for your Android project's build system
    // The versions here are common; your existing project might use slightly different ones
    // You can usually find the exact versions in an existing Flutter project's android/build.gradle.kts
    // If you have trouble building with these, we can adjust versions.
    id("com.android.application") version "8.10.1" apply false // Android Gradle Plugin
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false // Kotlin Gradle Plugin

    // THIS IS THE CRITICAL LINE FOR FIREBASE
    id("com.google.gms.google-services") version "4.3.15" apply false // Google Services Plugin
}

allprojects {
    repositories {
        google() // Essential for Firebase and other Google services
        mavenCentral() // Essential for general Android libraries
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}