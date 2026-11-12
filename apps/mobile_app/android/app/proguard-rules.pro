# Release builds only (R8). Debug builds are not shrunk.

# flutter_local_notifications stores scheduled notifications as JSON with Gson
# (reflection over its model classes and generic TypeToken): without these rules
# R8 renames the fields and every scheduled reminder fails in a release build.
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
