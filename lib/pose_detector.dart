import 'dart:async';

import 'package:flutter/services.dart';

import 'input_image.dart';

// Adapted from: https://github.com/flutter-ml/google_ml_kit_flutter/blob/master/packages/google_mlkit_pose_detection/lib/src/pose_detector.dart
// The code from that project is under the MIT licence, please see mit_licence.md

/// A detector for performing body-pose estimation.
class PoseDetector {

  /// The method channel to pass through the frames to detect
  static const MethodChannel _channel =
      MethodChannel('google_mediapipe_pose_detection');

  /// The options for the pose detector.
  final PoseDetectorOptions options;

  /// The event channel the native platforms stream back live detection from
  late final Stream<dynamic> _eventStream =
      const EventChannel("google_mediapipe_pose_detection_results")
          .receiveBroadcastStream()
          .map((event) => List<dynamic>.from(event));

  /// Allows listening of the results of the detection
  /// from the inputted live stream frames.
  StreamSubscription listenDetection(void Function(List<Pose> poses) onDetection) {
    return _eventStream.listen((event) {

      final List<Pose> poses = [];
      for (final pose in event) {
        final Map<PoseLandmarkType, PoseLandmark> landmarks = {};
        for (final point in pose) {
          final landmark = PoseLandmark.fromJson(point);
          landmarks[landmark.type] = landmark;
        }
        poses.add(Pose(landmarks: landmarks));
      }

      onDetection(poses);
  });
  }

  /// Instance id.
  final id = DateTime.now().microsecondsSinceEpoch.toString();

  /// Constructor to create an instance of [PoseDetector].
  PoseDetector({required this.options});

  /// Processes the given [InputImage] for pose detection.
  /// It returns a list of [Pose].
  Future<void> processImage(InputImage inputImage) async {
    await _channel.invokeMethod('startPoseDetector', <String, dynamic>{
      'options': options.toJson(),
      'imageData': inputImage.toJson()
    });
  }

  /// Closes the detector and releases its resources.
  Future<void> close() =>
      _channel.invokeMethod('closePoseDetector', {'id': id});
}

/// Determines the parameters on which [PoseDetector] works.
class PoseDetectorOptions {
  /// Specifies whether to use base or accurate pose model.
  final PoseDetectionModel model;

  /// The mode for the pose detector.
  final PoseDetectionRunningMode mode;

  final PoseDetectionDelegate delegate;

  /// The maximum number of poses that can be detected by the the Pose Landmarker.
  final int numPoses;

  /// The minimum confidence score for the pose detection to be considered successful.
  final double minPoseDetectionConfidence;

  /// The minimum confidence score of pose presence score in the pose landmark detection.
  final double minPosePresenceConfidence;

  /// The minimum confidence score for the pose tracking to be considered successful.
  final double minTrackingConfidence;

  // /// The minimum confidence score for the pose tracking to be considered successful.
  // final bool outputSegmentationMasks;
  //
  // /// Set to true if points should be in normalized space (0-1) rather then
  // /// it's pixel value in the image.
  // final bool useNormalizedCoordinates;

  /// Constructor to create an instance of [PoseDetectorOptions].
  PoseDetectorOptions({
    this.model = PoseDetectionModel.full,
    this.mode = PoseDetectionRunningMode.liveStream,
    this.delegate = PoseDetectionDelegate.GPU,
    this.numPoses = 1,
    this.minPoseDetectionConfidence = 0.5,
    this.minPosePresenceConfidence = 0.5,
    this.minTrackingConfidence = 0.5,
    // this.outputSegmentationMasks = false,
    // this.useNormalizedCoordinates = false,
  });

  /// Returns a json representation of an instance of [PoseDetectorOptions].
  Map<String, dynamic> toJson() => {
        'model': model.name,
        'mode': mode.name,
        'delegate': delegate.name,
        'numPoses': numPoses,
        'minPoseDetectionConfidence': minPoseDetectionConfidence,
        'minPosePresenceConfidence': minPosePresenceConfidence,
        'minTrackingConfidence': minTrackingConfidence,
        // 'outputSegmentationMasks': outputSegmentationMasks,
        // 'useNormalizedCoordinates': useNormalizedCoordinates,
      };
}

// Specifies whether to use base or accurate pose model.
enum PoseDetectionDelegate {
  /// Uses the CPU for processing poses.
  CPU,

  /// Uses the GPU for processing poses.
  GPU,
}

// Specifies whether to use base or accurate pose model.
enum PoseDetectionModel {
  /// Very fast model with low accuracy. Best for very old devices.
  lite,

  /// Default model with good a tradeoff between speed and accuracy.
  /// Best for live streaming.
  full,

  /// Slower model with high accuracy. Best when detection can be done slowly.
  heavy,

  /// Deprecated model, defaults to Full
  base,

  /// Deprecated model, defaults to heavy
  accurate,
}

/// The mode for the pose detector.
enum PoseDetectionRunningMode {
  /// Known as Image in Mediapipe.
  /// The mode for recognizing pose landmarks on single image inputs.
  single,

  /// The mode for recognizing pose landmarks on single image inputs.
  image,

  // NOT IMPLEMENTED: The mode for recognizing pose landmarks on the decoded frames of a video.
  // video,

  /// Known as Live Stream in Mediapipe. The mode for recognizing pose
  /// landmarks on a live stream of input data, such as from camera.
  stream,

  /// The mode for recognizing pose landmarks on a live stream of input data,
  /// such as from camera.
  liveStream,
}

/// Available pose landmarks detected by [PoseDetector].
enum PoseLandmarkType {
  nose,
  leftEyeInner,
  leftEye,
  leftEyeOuter,
  rightEyeInner,
  rightEye,
  rightEyeOuter,
  leftEar,
  rightEar,
  leftMouth,
  rightMouth,
  leftShoulder,
  rightShoulder,
  leftElbow,
  rightElbow,
  leftWrist,
  rightWrist,
  leftPinky,
  rightPinky,
  leftIndex,
  rightIndex,
  leftThumb,
  rightThumb,
  leftHip,
  rightHip,
  leftKnee,
  rightKnee,
  leftAnkle,
  rightAnkle,
  leftHeel,
  rightHeel,
  leftFootIndex,
  rightFootIndex
}

/// Describes a pose detection result.
class Pose {
  /// A map of all the landmarks in the detected pose.
  final Map<PoseLandmarkType, PoseLandmark> landmarks;

  /// Constructor to create an instance of [Pose].
  Pose({required this.landmarks});
}

/// A landmark in a pose detection result.
class PoseLandmark {
  /// The landmark type.
  final PoseLandmarkType type;

  /// Gives x coordinate of landmark in image frame.
  final double x;

  /// Gives y coordinate of landmark in image frame.
  final double y;

  /// Gives z coordinate of landmark in image space.
  final double z;

  /// The likelihood of the landmark existing within the scene.
  final double presence;

  /// The likelihood of the landmark being visible within the image.
  final double visibility;

  /// Constructor to create an instance of [PoseLandmark].
  PoseLandmark({
    required this.type,
    required this.x,
    required this.y,
    required this.z,
    required this.presence,
    required this.visibility,
  });

  /// Returns an instance of [PoseLandmark] from a given [json].
  factory PoseLandmark.fromJson(Map<dynamic, dynamic> json) {
    return PoseLandmark(
      type: PoseLandmarkType.values[json['type'].toInt()],
      x: json['x'],
      y: json['y'],
      z: json['z'],
      presence: json['presence'] ?? 0.0,
      visibility: json['visibility'] ?? 0.0,
    );
  }
}
