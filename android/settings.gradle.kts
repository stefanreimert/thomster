pluginManagement {
    val flutterSdkPath =
        run {
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
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.9.1" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}

include(":app")

// Workaround for spotify_sdk requiring a sibling Gradle project ':spotify-app-remote'.
// The Flutter plugin loader includes ':spotify_sdk', but not its nested dependency in some setups.
// Parse .flutter-plugins-dependencies to locate the plugin path, then include the nested module.
run {
    val depsFile = java.io.File(rootDir, ".flutter-plugins-dependencies")
    if (depsFile.exists()) {
        val content = depsFile.readText()
        val marker = "\"name\":\"spotify_sdk\""
        val idxPlugin = content.indexOf(marker)
        if (idxPlugin >= 0) {
            val pathKey = "\"path\":\""
            val idxPath = content.indexOf(pathKey, idxPlugin)
            if (idxPath >= 0) {
                val start = idxPath + pathKey.length
                val end = content.indexOf('"', start)
                if (end > start) {
                    val pluginPath = content.substring(start, end)
                    val appRemoteDir = java.io.File(pluginPath, "android/spotify-app-remote")
                    if (appRemoteDir.exists()) {
                        include(":spotify-app-remote")
                        project(":spotify-app-remote").projectDir = appRemoteDir
                    }
                }
            }
        }
    }
}
