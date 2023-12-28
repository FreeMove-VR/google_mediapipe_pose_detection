import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mediapipe_pose_detection/google_mediapipe_pose_detection.dart';
import 'package:google_mediapipe_pose_detection/input_image.dart';

import 'detector_view.dart';
import 'pose_painter.dart';

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

  void _processCurrentImage(InputImage inputImage) {
    currentImage = inputImage;
    _poseDetector.processImage(inputImage);
  }
}
