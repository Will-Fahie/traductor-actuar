import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    kotlin("android")
    id("dev.flutter.flutter-gradle-plugin")
}

fun localProperties(): Properties {
    val localPropertiesFile = rootProject.file("local.properties")
    val properties = Properties()
    if (localPropertiesFile.exists()) {
        properties.load(localPropertiesFile.inputStream())
    }
    return properties
}

val flutterVersionCode: String by lazy {
    localProperties().getProperty("flutter.versionCode") ?: "1"
}
val flutterVersionName: String by lazy {
    localProperties().getProperty("flutter.versionName") ?: "1.0"
}

// Correctly load keystore properties from android/key.properties
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("android/key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.example.myapp"
    compileSdk = 35
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
    }

    defaultConfig {
        applicationId = "com.willfahie.traductorachuar"
        minSdk = 21
        targetSdk = 35
        versionCode = flutterVersionCode.toInt()
        versionName = flutterVersionName
    }

    signingConfigs {
        create("release") {
            // Use safe casting to avoid null pointer exceptions
            keyAlias = "upload"
            keyPassword = "poacher1!"
            // The path is relative to the app module directory
            storeFile = file("upload-keystore.jks")
            storePassword = "poacher1!"
    }
    }

    buildTypes {
        release {
            // Only use the release signing config
            signingConfig = signingConfigs.getByName("release")
        }
    }
    }

flutter {
    source = "../.."
}

dependencies {
}
