# Keep Flutter's main activity
-keep class com.mitossoftwaresolutions.morsecomms.MainActivity { *; }

# Keep all classes referenced in AndroidManifest
-keep public class * extends android.app.Activity
-keep public class * extends android.app.Application
