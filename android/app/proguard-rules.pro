# Flutter specific rules - keep everything Flutter related
-keep class io.flutter.** { *; }
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

# Permission handler plugin
-keep class com.baseflow.permissionhandler.** { *; }
-keep class com.baseflow.** { *; }

# Path provider plugin
-keep class io.flutter.plugins.pathprovider.** { *; }
-keep class androidx.core.content.FileProvider { *; }

# File picker plugin (miguelruivo)
-keep class com.mr.flutter.plugin.filepicker.** { *; }
-keep class miguelruivo.flutter.plugins.filepicker.** { *; }

# Wechat assets picker
-keep class com.fluttercandies.** { *; }

# Android Intent plugin
-keep class com.pichillilorenzo.** { *; }
-keep class android_intent_plus.** { *; }

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
-keep class androidx.media3.** { *; }

# Notification plugin rules
-keep class com.dexterous.** { *; }

# Keep all Pigeon-generated classes (used by path_provider and others)
-keep class dev.flutter.pigeon.** { *; }

# Keep all classes in the app's package
-keep class com.ashwinsharma.vixel.** { *; }

# Keep Kotlin metadata and coroutines
-keep class kotlin.** { *; }
-keep class kotlin.Metadata { *; }
-keep class kotlinx.coroutines.** { *; }
-keepattributes RuntimeVisibleAnnotations
-keepattributes *Annotation*

# Keep AndroidX classes
-keep class androidx.** { *; }
-keep interface androidx.** { *; }

# Suppress warnings
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**
