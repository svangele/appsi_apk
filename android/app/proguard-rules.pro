# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Keep attributes
-keepattributes InnerClasses
-keepattributes EnclosingMethod
-keepattributes *Annotation*

# Keep generic signature
-keep,allowobfuscation,allowshrinking class kotlin.coroutines.Continuation

# AndroidX Window extensions (ignore missing classes)
-dontwarn androidx.window.extensions.**
-keep class androidx.window.extensions.** { *; }
-dontwarn androidx.window.sidecar.**
-keep class androidx.window.sidecar.** { *; }

# Google Play Core (ignore missing classes)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
