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

  var firstTime = true;

  CustomPaint? _customPaint;
  String? _text;
  var _cameraLensDirection = CameraLensDirection.back;

  InputImage? currentImage;

  var time = 0;
  var frameCounter = 0;

  @override
  void dispose() async {
    _poseDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        home: Scaffold(
            body: DetectorView(
      title: 'Pose Detector',
      customPaint: _customPaint,
      text: _text,
      onImage: _updateFrame,
      initialCameraLensDirection: _cameraLensDirection,
      onCameraLensDirectionChanged: (value) => _cameraLensDirection = value,
    )));
  }

  Future<void> _updateFrame(InputImage inputImage) async {

    frameCounter++;
    if (time != DateTime.now().second)
    {
      time = DateTime.now().second;
      print("Frame Count: $frameCounter");
      frameCounter = 0;
    }


    if(firstTime) {
      _sendImage(inputImage);
      firstTime = false;
      return;
    }

    final result = await _poseDetector.readResult();

    if (result != null) {
      _processPose(result);
      _sendImage(inputImage);
    }
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

  Future<void> _sendImage(InputImage inputImage) async {
    currentImage = inputImage;
    await _poseDetector.processImage(inputImage);
  }
}
