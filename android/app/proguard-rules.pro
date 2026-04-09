# Keep Flutter's main activity
-keep class com.mitossoftwaresolutions.morsecomms.MainActivity { *; }

# Flutter embedding keep rules
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }

# Keep all classes referenced in AndroidManifest
-keep public class * extends android.app.Activity
-keep public class * extends android.app.Application

# Flutter references Play Core for deferred components, but we don't use that feature.
# Suppress missing-class warnings so R8 doesn't fail the build.
-dontwarn com.google.android.play.core.**
