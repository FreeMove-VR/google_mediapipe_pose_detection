package com.freemovevr.google_mediapipe_pose_detection

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/** GoogleMediapipePoseDetectionPlugin */
class GoogleMediapipePoseDetectionPlugin: FlutterPlugin {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channel : MethodChannel
  private var resultChannel: EventChannel? = null

  private var poseDetector:PoseDetector? = null

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    poseDetector = PoseDetector(flutterPluginBinding.applicationContext, flutterPluginBinding)
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "google_mediapipe_pose_detection")
    channel.setMethodCallHandler(poseDetector)

    resultChannel = EventChannel(flutterPluginBinding.binaryMessenger, "google_mediapipe_pose_detection_results")
    resultChannel!!.setStreamHandler(poseDetector)

    // Create and start a new thread for live feed detection
    val detectionThread = Thread {
      while (true) {
        poseDetector?.detectSavedImage()
      }
    }

    detectionThread.start()
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }
}
