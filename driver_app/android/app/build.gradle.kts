plugins {

    id("com.android.application")

    id("kotlin-android")

    id("dev.flutter.flutter-gradle-plugin")

}



import java.util.Properties

import java.io.FileInputStream



val keystorePropertiesFile = rootProject.file("key.properties")

val keystoreProperties = Properties()

if (keystorePropertiesFile.exists()) {

    keystoreProperties.load(FileInputStream(keystorePropertiesFile))

}



android {

    namespace = "com.korolidorog.driver"

    compileSdk = flutter.compileSdkVersion

    ndkVersion = flutter.ndkVersion



    compileOptions {

        sourceCompatibility = JavaVersion.VERSION_17

        targetCompatibility = JavaVersion.VERSION_17

        isCoreLibraryDesugaringEnabled = true

    }



    kotlinOptions {

        jvmTarget = JavaVersion.VERSION_17.toString()

    }



    signingConfigs {

        if (keystorePropertiesFile.exists()) {

            create("release") {

                keyAlias = keystoreProperties["keyAlias"] as String

                keyPassword = keystoreProperties["keyPassword"] as String

                storeFile = file(keystoreProperties["storeFile"] as String)

                storePassword = keystoreProperties["storePassword"] as String

            }

        }

    }



    defaultConfig {

        applicationId = "com.korolidorog.driver"

        minSdk = maxOf(flutter.minSdkVersion, 26)

        targetSdk = flutter.targetSdkVersion

        versionCode = flutter.versionCode

        versionName = flutter.versionName

    }



    buildTypes {

        release {

            signingConfig = if (keystorePropertiesFile.exists()) {

                signingConfigs.getByName("release")

            } else {

                signingConfigs.getByName("debug")

            }

        }

    }

}



flutter {

    source = "../.."

}



dependencies {

    implementation("com.google.android.gms:play-services-location:21.1.0")

    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

}



if (file("google-services.json").exists()) {

    apply(plugin = "com.google.gms.google-services")

}

