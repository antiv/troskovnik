import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Upload keystore za Play App Signing. Tajne se čitaju iz android/key.properties
// (NIJE u gitu). Ako fajl ne postoji (npr. CI bez tajni), pada na debug potpis.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseSigning = keystorePropertiesFile.exists()
if (hasReleaseSigning) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "rs.antonijevic.troskovnik"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Potrebno za flutter_local_notifications (core library desugaring).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "rs.antonijevic.troskovnik"
        // minSdk 23: zahtevi SQLCipher-a i lokalnih notifikacija.
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = (keystoreProperties["storeFile"] as String).let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Potpisuj release upload ključem ako postoji key.properties,
            // inače debug (da `flutter run --release` radi i bez keystore-a).
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // R8/shrink ISKLJUČEN: minify je strip-ovao native kod plugina
            // (SQLCipher/FFI) pa je release crashovao pri pokretanju na uređaju.
            // Dart kod je AOT-kompajliran (R8 ga ne dira), pa je dobitak mali,
            // a rizik veliki. proguard-rules.pro zadržan za eventualno kasnije.
            isMinifyEnabled = false
            isShrinkResources = false
            // Upakuj native debug simbole (libflutter.so, libapp.so, SQLCipher…)
            // u AAB radi čitljivih native crash-eva u Play Console-u.
            ndk {
                debugSymbolLevel = "FULL"
            }
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
