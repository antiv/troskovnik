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
    // compileSdk 37 umesto Flutter-ovog podrazumevanog 36: flutter_secure_storage
    // 11 se gradi protiv 37 (vidi android/build.gradle u tom paketu), a AGP
    // traži da aplikacija kompajlira bar protiv najviše verzije svojih
    // zavisnosti. Vratiti na flutter.compileSdkVersion kad Flutter stigne na 37.
    compileSdk = maxOf(flutter.compileSdkVersion, 37)
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Potrebno za flutter_local_notifications (core library desugaring).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "rs.antonijevic.troskovnik"
        // SQLCipher i lokalne notifikacije traže 23, flutter_secure_storage 11
        // traži 24 — merodavan je najviši. Flutter na 3.44.x i sam podrazumeva
        // 24, pa je efektivni minSdk i pre ove izmene bio 24, a ne 23; maxOf
        // stoji da prag ostane izričit ako se Flutter ikad spusti.
        minSdk = maxOf(flutter.minSdkVersion, 24)
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
