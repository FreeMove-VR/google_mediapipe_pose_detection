import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'google_mediapipe_pose_detection_method_channel.dart';

abstract class GoogleMediapipePoseDetectionPlatform extends PlatformInterface {
  /// Constructs a GoogleMediapipePoseDetectionPlatform.
  GoogleMediapipePoseDetectionPlatform() : super(token: _token);

  static final Object _token = Object();

  static GoogleMediapipePoseDetectionPlatform _instance = MethodChannelGoogleMediapipePoseDetection();

  /// The default instance of [GoogleMediapipePoseDetectionPlatform] to use.
  ///
  /// Defaults to [MethodChannelGoogleMediapipePoseDetection].
  static GoogleMediapipePoseDetectionPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [GoogleMediapipePoseDetectionPlatform] when
  /// they register themselves.
  static set instance(GoogleMediapipePoseDetectionPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
