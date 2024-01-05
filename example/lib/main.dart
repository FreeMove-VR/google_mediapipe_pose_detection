import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mediapipe_pose_detection/google_mediapipe_pose_detection.dart';
import 'package:google_mediapipe_pose_detection/input_image.dart';

import 'detector_view.dart';
import 'pose_painter.dart';

// Pulled directly with minor edits from: https://github.com/flutter-ml/google_ml_kit_flutter/blob/develop/packages/example/lib/vision_detector_views/pose_detector_view.dart
// The code from that project is under the MIT licence, please see mit_licence.md

void main() {
  runApp(const PoseDetectorView());
}

class PoseDetectorView extends StatefulWidget {
  const PoseDetectorView({super.key});

  @override
  State<StatefulWidget> createState() => _PoseDetectorViewState();
}

class _PoseDetectorViewState extends State<PoseDetectorView> {
  final PoseDetector _poseDetector =
      PoseDetector(options: PoseDetectorOptions());

  CustomPaint? _customPaint;
  String? _text;
  var _cameraLensDirection = CameraLensDirection.back;

  InputImage? currentImage;

  @override
  void dispose() async {
    _poseDetector.close();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    //ADDED CODE
    // Listen to the results the pose detector gets back and update when we
    // receive a new pose
    _poseDetector.listenDetection((poses) {
      _processPose(poses);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        home: Scaffold(
            body: DetectorView(
      title: 'Pose Detector',
      customPaint: _customPaint,
      text: _text,
      onImage: _processCurrentImage,
      initialCameraLensDirection: _cameraLensDirection,
      onCameraLensDirectionChanged: (value) => _cameraLensDirection = value,
    )));
  }

  // ADDED CODE
  // We set up a listener so that when Mediapipe is done processing an image,
  // we can do work here
  Future<void> _processPose(List<Pose> poses) async {
    if (currentImage?.metadata?.size != null &&
        currentImage?.metadata?.rotation != null) {
      final painter = PosePainter(
        poses,
        currentImage!.metadata!.size,
        currentImage!.metadata!.rotation,
        _cameraLensDirection,
      );
      _customPaint = CustomPaint(painter: painter);
    }
    if (mounted) {
      setState(() {});
    }
  }

  // ADDED CODE
  // OnImage now only sends the image to the library
  void _processCurrentImage(InputImage inputImage) {
    currentImage = inputImage;
    _poseDetector.processImage(inputImage);
  }
}
