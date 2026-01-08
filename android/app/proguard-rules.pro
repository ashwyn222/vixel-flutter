# Flutter specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Permission handler plugin
-keep class com.baseflow.permissionhandler.** { *; }

# Path provider plugin
-keep class io.flutter.plugins.pathprovider.** { *; }

# File picker plugin
-keep class com.mr.flutter.plugin.filepicker.** { *; }

# Wechat assets picker
-keep class com.fluttercandies.** { *; }

# Android Intent plugin
-keep class com.pichillilorenzo.** { *; }

# Open file plugin
-keep class com.crazecoder.openfile.** { *; }

# Shared preferences plugin
-keep class io.flutter.plugins.sharedpreferences.** { *; }

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

# Keep all Pigeon-generated classes (used by path_provider and others)
-keep class dev.flutter.pigeon.** { *; }

# Keep Kotlin metadata
-keep class kotlin.Metadata { *; }
-keepattributes RuntimeVisibleAnnotations

# Google Play Core (for deferred components - not used but referenced by Flutter)
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
