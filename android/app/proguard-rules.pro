# R8/ProGuard pravila za release build.

# Flutter Engine & Plugins
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Očuvaj sve native (JNI/FFI) metode — neophodno za DynamicLibrary.open i SQLCipher
-keepclasseswithmembernames class * {
    native <methods>;
}

# SQLCipher (net.zetetic) + sqlite3 native & wrapper
-keep class net.zetetic.** { *; }
-dontwarn net.zetetic.**
-keep class eu.simonbinder.** { *; }
-dontwarn eu.simonbinder.**

# flutter_secure_storage (enkripcija ključa baze)
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# workmanager / WorkManager (pozadinski refetch računa)
-keep class * extends androidx.work.Worker
-keep class * extends androidx.work.ListenableWorker { *; }
-keep class dev.fluttercommunity.workmanager.** { *; }

# flutter_local_notifications (reflektivni pristup + desugaring)
-keep class com.dexterous.** { *; }
-dontwarn com.dexterous.**

# mobile_scanner & CameraX & JNI
-keep class dev.steenbakker.mobile_scanner.** { *; }
-keep class androidx.camera.** { *; }
-dontwarn androidx.camera.**
-keep class com.github.dart_lang.jni.** { *; }

# in_app_review (Play Review API)
-keep class com.google.android.play.core.review.** { *; }
-keep class dev.britannio.in_app_review.** { *; }

# file_picker & share_plus & package_info_plus
-keep class com.mr.flutter.plugin.filepicker.** { *; }
-keep class dev.fluttercommunity.plus.** { *; }

# Opšte: zadrži anotacije i potpise generika (drift/serijalizacija)
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod
