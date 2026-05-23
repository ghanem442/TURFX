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
-keep class com.example.football.** { *; }
