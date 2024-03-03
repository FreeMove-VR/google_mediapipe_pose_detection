import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:google_mediapipe_pose_detection/input_image.dart';

// Pulled directly from: https://github.com/flutter-ml/google_ml_kit_flutter/blob/develop/packages/example/lib/vision_detector_views/painters/coordinates_translator.dart
// The code from that project is under the MIT licence, please see mit_licence.md

double translateX(
    double x,
    Size canvasSize,
    Size imageSize,
    InputImageRotation rotation,
    CameraLensDirection cameraLensDirection,
    ) {

  switch (rotation) {
    case InputImageRotation.rotation90deg:
      return x *
          canvasSize.width / imageSize.height;
    case InputImageRotation.rotation270deg:
      return canvasSize.width -
          x *
              canvasSize.width / imageSize.height;
    case InputImageRotation.rotation0deg:
    case InputImageRotation.rotation180deg:
      switch (cameraLensDirection) {
        case CameraLensDirection.back:
          return x * canvasSize.width / imageSize.width;
        default:
          return canvasSize.width - x * canvasSize.width / imageSize.width;
      }
  }
}

double translateY(
    double y,
    Size canvasSize,
    Size imageSize,
    InputImageRotation rotation,
    CameraLensDirection cameraLensDirection,
    ) {
  switch (rotation) {
    case InputImageRotation.rotation90deg:
    case InputImageRotation.rotation270deg:
      return y *
          canvasSize.height / imageSize.width;
    case InputImageRotation.rotation0deg:
    case InputImageRotation.rotation180deg:
      return y * canvasSize.height / imageSize.height;
  }
}
