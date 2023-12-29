//
//  PoseDetector.swift
//  google_mediapipe_pose_detection
//
//  Created by William Parker on 28/12/2023.
//

import Foundation
import Flutter

public class PoseDetector: NSObject, FlutterPlugin, FlutterStreamHandler {
    
    var eventSink: FlutterEventSink?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let poseDetector = PoseDetector()

        let methodChannel = FlutterMethodChannel(name: "google_mediapipe_pose_detection", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(poseDetector, channel: methodChannel)
          
        let eventChannel = FlutterEventChannel(name: "google_mediapipe_pose_detection_results", binaryMessenger: registrar.messenger())
        
        DispatchQueue.global().async {
            poseDetector.detectSavedImage()
        }
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startPoseDetector":
            handleDetection(call: call, result: result)
        case "closePoseDetector":
            closeDetector()
            result(nil)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    public func handleDetection(call: FlutterMethodCall, result: @escaping FlutterResult) {
        
    }
    
    public func detectSavedImage() {
        
    }
    
    public func setupPoseLandmarker() {
        
    }
    
    public func returnLivestreamResult() {
        
    }
    
    public func returnLivestreamError() {
        
    }
    
    public func convertPoseData() {
        
    }
    
    public func closeDetector() {
        
    }

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}
