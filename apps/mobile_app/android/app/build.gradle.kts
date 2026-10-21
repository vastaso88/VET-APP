import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing is read from android/key.properties (git-ignored, created and
// kept by the owner - never committed). Without that file a release build still
// works but is signed with the debug key, as before. Expected keys: storeFile
// (path relative to this app/ folder), storePassword, keyAlias, keyPassword.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

android {
    namespace = "com.vetapp.vetapp"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Required by flutter_local_notifications' scheduled notifications.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.vetapp.vetapp"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Three apps that live side by side on one phone, one per track. `prod`
    // keeps the original application id (the future Play Store listing); the
    // others add a suffix so they install next to it. Not called "main": that
    // would collide with the `main` source set. Always build with --flavor,
    // see docs/runbooks/android_flavors.md.
    buildFeatures {
        // Per-flavor app_name (see productFlavors below).
        resValues = true
    }

    flavorDimensions += "track"
    productFlavors {
        create("prod") {
            dimension = "track"
            resValue("string", "app_name", "VetApp")
        }
        create("francesco") {
            dimension = "track"
            applicationIdSuffix = ".francesco"
            resValue("string", "app_name", "VetApp Francesco")
        }
        create("roberto") {
            dimension = "track"
            applicationIdSuffix = ".roberto"
            resValue("string", "app_name", "VetApp Roberto")
        }
    }

    signingConfigs {
        if (keystoreProperties.getProperty("storeFile") != null) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // The owner's release key when android/key.properties exists, the
            // debug key otherwise, so `flutter run --release` keeps working.
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
            // R8 shrinks release builds: keep what plugins reach by reflection.
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
