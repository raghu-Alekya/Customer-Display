pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
<<<<<<< HEAD
=======
        maven("https://jitpack.io")
>>>>>>> origin/Grocery_pch_api_integration
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
<<<<<<< HEAD
    id("com.android.application") version "8.7.0" apply false
    id("org.jetbrains.kotlin.android") version "2.2.10" apply false
}

include(":app")
=======
    id("com.android.application") version "8.9.1" apply false
    // Updated to Kotlin 2.1.0 to satisfy Flutter's minimum supported version
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
    repositories {
        google()
        mavenCentral()
        maven("https://jitpack.io")
        maven("https://storage.googleapis.com/download.flutter.io")   // ⭐ ADD THIS
    }
}

include(":app")
>>>>>>> origin/Grocery_pch_api_integration
