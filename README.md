# Google Mediapipe Pose Detection

This is a Flutter plugin for using Pose detection in Google's Mediapipe in Flutter. 
This project takes heavily from [Google's example code on Mediapipe](https://github.com/googlesamples/mediapipe/tree/main) 
which is under the MIT Licence and 
the [google_ml_kit_flutter](https://github.com/flutter-ml/google_ml_kit_flutter/tree/develop) plugin
which is under the Apache-2.0 license. Please see mit_licence.md and apache_2_0_licence.md respectively.

This project was initially meant to be a drop in replacement / upgrade for google_ml_kit_flutter. 
Due to Mediapipe's technical differences from ML Kit, pose results are read from a stream in this plugin.

There are some slight differences in the options to create the landmarker as well.

While Mediapipe v0.10.8 introduced pose detection on iOS, on Cocoapods, 
MediaPipeTasksVision is still at v0.10.5. We will fix and merge the iOS branch to add iOS support 
once the library is available through Cocoapods.