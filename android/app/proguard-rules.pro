# ZCS SmartPos SDK is reflection-heavy and ships no consumer rules. R8 only runs
# on release, so without this the printer works in debug and dies in the field.
-keep class com.zcs.** { *; }
-dontwarn com.zcs.**
-keep class com.google.zxing.** { *; }
-dontwarn com.google.zxing.**
