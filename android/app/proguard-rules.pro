# Flutter specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# FFmpeg Kit rules
-keep class com.arthenica.ffmpegkit.** { *; }
-keep class com.arthenica.smartexception.** { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Video player rules
-keep class com.google.android.exoplayer2.** { *; }

# Notification plugin rules
-keep class com.dexterous.** { *; }

# Google Play Core (for deferred components - not used but referenced by Flutter)
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
