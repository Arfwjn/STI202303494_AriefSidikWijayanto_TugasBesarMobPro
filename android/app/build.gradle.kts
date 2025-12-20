plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties

// Load local.properties
val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { stream ->
        localProperties.load(stream)
    }
}

// Get Google Maps API Key
val googleMapsApiKey = localProperties.getProperty("googleMapsApiKey")
    ?: System.getenv("GOOGLE_MAPS_API_KEY")
    ?: "AIzaSyCkknVRZSvyOd9CIxu1PTXsJu5LNjqjNkY" // Fallback

android {
    namespace = "com.example.travvels"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.travvels"
        minSdkVersion (21)
        targetSdkVersion(flutter.targetSdkVersion)
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // Inject API key to manifest
        manifestPlaceholders["googleMapsApiKey"] = googleMapsApiKey
        
        // Debug log
        println("Google Maps API Key: ${googleMapsApiKey.take(10)}...")
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}