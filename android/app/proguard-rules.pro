# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

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

# Keep model classes used for JSON serialization
-keep class ahmed.turfx.com.** { *; }
-keep class com.example.football.** { *; }

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

# Play Core compatibility for deferred components
-keep class com.google.android.play.core.** { *; }

# Keep Play Core classes for Flutter deferred components
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# Additional Flutter embedding rules
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**
-keep class * extends io.flutter.embedding.engine.plugins.FlutterPlugin { *; }
