# Google Mediapipe Pose Detection

This is a Flutter plugin for using Pose detection in Google's Mediapipe in Flutter. 
This project takes heavily from [Google's example code on Mediapipe](https://github.com/googlesamples/mediapipe/tree/main) 
which is under the MIT Licence and 
the [google_ml_kit_flutter](https://github.com/flutter-ml/google_ml_kit_flutter/tree/develop) plugin
which is under the Apache-2.0 license. Please see mit_licence.md and apache_2_0_licence.md respectively.

This project was initially meant to be a drop in replacement / upgrade for google_ml_kit_flutter. 
Due to Mediapipe's technical differences from ML Kit, the following needed to be changed:

- Pose results are read from a stream.
- There are differences in the options to create the landmarker.
- Mediapipe cannot handle being minified. To fix this, do the following:
  - In `example\android\app\build.gradle` add line 61 to your code, which specifies a proguard file.
  - Add the `proguard-rules.pro` file alongside `example\android\app\build.gradle`. This will stop Mediapipe from minifying while keeping Flutter working.
