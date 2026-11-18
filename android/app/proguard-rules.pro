# ML Kit text recognition: the Flutter plugin compiles against the Chinese,
# Devanagari, Japanese and Korean recognizers but SplitMate only ships Latin.
# Without these lines R8 fails the release build on the missing classes.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# ML Kit wires its internals together by reflection. Shrunk, the first scan
# crashed with a NullPointerException inside mlkit_vision_common, so keep it.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_** { *; }
-keep class com.google.android.gms.vision.** { *; }
-keep class com.google_mlkit_commons.** { *; }
-keep class com.google_mlkit_text_recognition.** { *; }

# Firebase finds its components by reflection (no-arg constructors). Shrunk,
# Crashlytics failed to start ("Could not instantiate CrashlyticsRegistrar").
-keep class * implements com.google.firebase.components.ComponentRegistrar { <init>(); }
-keep class com.google.firebase.crashlytics.** { *; }
-keep class com.google.firebase.sessions.** { *; }
