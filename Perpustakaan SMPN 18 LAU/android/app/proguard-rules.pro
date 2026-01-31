# Optimization rules for Firebase & Flutter libraries
-optimizationpasses 5
-verbose

# Keep all Flutter/Dart-related classes
-keep class io.flutter.** { *; }
-keep class androidx.** { *; }

# Firebase - keep these classes for proper operation
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-keep class com.firebase.** { *; }

# Keep model classes
-keep class com.example.flutter_application_1.** { *; }
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# For cloud_firestore
-keep class com.google.firebase.firestore.** { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Remove logging in release builds
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}

# Optimize (but not obfuscate) with aggressive optimization
-allowaccessmodification
-repackageclasses
