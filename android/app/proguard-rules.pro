# Flutter - Keep ALL Flutter classes
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.embedding.android.FlutterActivity { *; }
-keep class io.flutter.embedding.android.FlutterFragmentActivity { *; }

# Keep MainActivity explicitly
-keep class ahmed.turfx.com.MainActivity { *; }
-keep class ahmed.turfx.com.** { *; }

# Multidex
-keep class androidx.multidex.** { *; }

# Firebase
-keep class com.firebase.** { *; }
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Riverpod
-keep class riverpod.** { *; }
-keep class flutter_riverpod.** { *; }

# Keep BuildConfig
-keep class **.BuildConfig { *; }

# Keep R classes
-keepclassmembers class **.R$* {
    public static <fields>;
}

# Preserve line numbers for debugging
-keepattributes SourceFile,LineNumberTable

# Keep all data models and DTOs
-keep class **.models.** { *; }
-keep class **.data.** { *; }

# Keep Freezed generated classes
-keep class **.freezed.** { *; }

# JSON serialization
-keepattributes *Annotation*
-keepattributes Signature
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
-keep class com.google.gson.** { *; }
-keep class org.json.** { *; }

# Dio / OkHttp
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**

# Keep data classes with JSON annotations
-keepclasseswithmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
-keep @interface com.google.gson.annotations.SerializedName

# Play Core
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# Flutter embedding - explicitly keep all
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class * extends io.flutter.embedding.engine.plugins.FlutterPlugin { *; }
-keep class * extends io.flutter.plugin.common.MethodCallHandler { *; }
-dontwarn io.flutter.embedding.**

# GeneratedPluginRegistrant
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }

# flutter_secure_storage - CRITICAL: prevents ClassNotFoundException crash & auto-logout
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-keep class androidx.security.crypto.** { *; }
-keep class androidx.security.** { *; }
-dontwarn androidx.security.**
-keep class com.google.crypto.tink.** { *; }
-dontwarn com.google.crypto.tink.**

# EncryptedSharedPreferences (used by flutter_secure_storage)
-keep class androidx.security.crypto.EncryptedSharedPreferences { *; }
-keep class androidx.security.crypto.MasterKey { *; }
-keep class androidx.security.crypto.MasterKey$Builder { *; }

# Keep all plugin classes to prevent ClassNotFoundException
-keep class ** implements io.flutter.embedding.engine.plugins.FlutterPlugin { *; }
-keep class ** implements io.flutter.plugin.common.MethodCallHandler { *; }

# Prevent R8 from stripping needed classes
-keepclassmembers class * {
    @androidx.annotation.Keep *;
}

