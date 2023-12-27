import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'google_mediapipe_pose_detection_platform_interface.dart';

/// An implementation of [GoogleMediapipePoseDetectionPlatform] that uses method channels.
class MethodChannelGoogleMediapipePoseDetection extends GoogleMediapipePoseDetectionPlatform {

  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('google_mediapipe_pose_detection');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
