# R8/ProGuard pravila za release build.

# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# SQLCipher (net.zetetic) + sqlite3 native
-keep class net.sqlcipher.** { *; }
-dontwarn net.sqlcipher.**

# workmanager / WorkManager
-keep class * extends androidx.work.Worker
-keep class * extends androidx.work.ListenableWorker { *; }

# flutter_local_notifications (reflektivni pristup + desugaring)
-keep class com.dexterous.** { *; }
-dontwarn com.dexterous.**

# Opšte: zadrži anotacije i potpise generika (drift/serijalizacija)
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod
