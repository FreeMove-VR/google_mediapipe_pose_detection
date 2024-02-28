#Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Mediapipe
-keep class com.google.mediapipe.solutioncore.** {*;}
-keep class com.google.protobuf.** {*;}
-keepclassmembers class * extends com.google.protobuf.GeneratedMessageLite {
  <fields>;
}