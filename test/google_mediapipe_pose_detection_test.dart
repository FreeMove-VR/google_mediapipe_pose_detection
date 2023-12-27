import 'package:flutter_test/flutter_test.dart';
import 'package:google_mediapipe_pose_detection/google_mediapipe_pose_detection.dart';
import 'package:google_mediapipe_pose_detection/google_mediapipe_pose_detection_platform_interface.dart';
import 'package:google_mediapipe_pose_detection/google_mediapipe_pose_detection_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockGoogleMediapipePoseDetectionPlatform
    with MockPlatformInterfaceMixin
    implements GoogleMediapipePoseDetectionPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final GoogleMediapipePoseDetectionPlatform initialPlatform = GoogleMediapipePoseDetectionPlatform.instance;

  test('$MethodChannelGoogleMediapipePoseDetection is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelGoogleMediapipePoseDetection>());
  });

  test('getPlatformVersion', () async {
    GoogleMediapipePoseDetection googleMediapipePoseDetectionPlugin = GoogleMediapipePoseDetection();
    MockGoogleMediapipePoseDetectionPlatform fakePlatform = MockGoogleMediapipePoseDetectionPlatform();
    GoogleMediapipePoseDetectionPlatform.instance = fakePlatform;

    expect(await googleMediapipePoseDetectionPlugin.getPlatformVersion(), '42');
  });
}
