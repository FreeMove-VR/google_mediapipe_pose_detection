//
//  PoseDetector.swift
//  google_mediapipe_pose_detection
//
//  Created by William Parker on 28/12/2023.
//

import Foundation
import Flutter
import MediaPipeTasksVision

var isWorking = false

var eventSink: FlutterEventSink?

public class PoseDetector: NSObject, FlutterPlugin, FlutterStreamHandler {
    
    var poseLandmarker: PoseLandmarker?
    
    var savedImage: MPImage?
    
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
            result(nil)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    public func handleDetection(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let imageData = args["imageData"] as? [String: Any],
              let mpImage = InputImageConverter.visionImage(from: imageData, result: result),
              let options = args["options"] as? [String: Any],
              let mode = options["mode"] as? String
        else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
            return
        }
        
        if poseLandmarker == nil
        {
            setupPoseLandmarker(options: options, result: result)
        }
        
        if poseLandmarker == nil
        {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Could not create poseLandmarker", details: nil))
            return
        }
        
        if mode == "image"
        {
            isWorking = true
            do
            {
                let detectionResult = try poseLandmarker!.detect(image: mpImage)
                
                isWorking = false
                
                let landmarkResult: [[[String: Any]]] = PoseLandmarkerResultProcessor.convertPoseData(poseLandmarkerResult: detectionResult)
                
                result(landmarkResult)
            }
            catch
            {
                isWorking = false
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Could not detect image", details: nil))
            }
        }
        else if mode == "liveStream"
        {
            savedImage = mpImage
        }
        
    }
    
    public func detectSavedImage() {
        if !isWorking && savedImage != nil {
            isWorking = true
            
            do
            {
                let frameTime = Int(CACurrentMediaTime() * 1000)
                try poseLandmarker?.detectAsync(image:savedImage!, timestampInMilliseconds: frameTime)
                savedImage = nil
            }
            catch
            {
                savedImage = nil
                isWorking = false
            }
        }
    }
    
    public func setupPoseLandmarker(options: [String: Any], result: @escaping FlutterResult) {
        guard let model = options["model"] as? String,
              let minPoseDetectionConfidence = options["minPoseDetectionConfidence"] as? Double,
              let minPosePresenceConfidence = options["minPosePresenceConfidence"] as? Double,
              let minPoseTrackingConfidence = options["minTrackingConfidence"] as? Double,
              let mode = options["mode"] as? String
        else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
            return
        }
        
        var modelPath = "assets/"
        
        switch model {
        case "full":
            modelPath += "pose_landmarker_full"
        case "lite":
            modelPath += "pose_landmarker_lite"
        case "heavy":
            modelPath += "pose_landmarker_heavy"
        default:
            modelPath += "pose_landmarker_full"
        }
        
        let key = FlutterDartProject.lookupKey(forAsset: modelPath, fromPackage: "google_mediapipe_pose_detection")
        let path: String? = Bundle.main.path(forResource: key, ofType: "task")
        
        if path == nil
        {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Cannot find task", details: nil))
            return
        }
        
        let options = PoseLandmarkerOptions()
        options.baseOptions.modelAssetPath = path!
        options.minPoseDetectionConfidence = Float(minPoseDetectionConfidence)
        options.minPosePresenceConfidence = Float(minPosePresenceConfidence)
        options.minTrackingConfidence = Float(minPoseTrackingConfidence)
        
        if mode == "liveStream"
        {
            options.runningMode = .liveStream
            let processor = PoseLandmarkerResultProcessor()
            options.poseLandmarkerLiveStreamDelegate = processor
        }
        else if mode == "image"
        {
            options.runningMode = .image
        }
        
        do {
            poseLandmarker = try PoseLandmarker(options: options)
        }
        catch {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Failed to create poseLandmarker", details: nil))
        }
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

class PoseLandmarkerResultProcessor: NSObject, PoseLandmarkerLiveStreamDelegate {
    
    func poseLandmarker(
        _ poseLandmarker: PoseLandmarker,
        didFinishDetection result: PoseLandmarkerResult?,
        timestampInMilliseconds: Int,
        error: Error?) {
            
            if error != nil
            {
                print(error?.localizedDescription ?? "Unkown Error")
                return
            }
            
            isWorking = false
            
            if result != nil
            {
                let landmarkList: [[[String: Any]]] = PoseLandmarkerResultProcessor.convertPoseData(poseLandmarkerResult: result!)
                
                DispatchQueue.main.async {
                    eventSink?(landmarkList)
                }
            }
        }
    
    public static func convertPoseData(poseLandmarkerResult: PoseLandmarkerResult) -> [[[String: Any]]] {
        var landmarkArray: [[Dictionary<String, Any>]] = []
        
        if !poseLandmarkerResult.landmarks.isEmpty {
            for pose in poseLandmarkerResult.landmarks {
                var landmarks: [Dictionary<String, Any>] = []
                
                for (index, landmark) in pose.enumerated() {
                    var landmarkMap: [String: Any] = [:]
                    
                    landmarkMap["type"] = index
                    landmarkMap["x"] = landmark.x
                    landmarkMap["y"] = landmark.y
                    landmarkMap["z"] = landmark.z
                    landmarkMap["presence"] = landmark.presence ?? 0.0
                    landmarkMap["visibility"] = landmark.visibility ?? 0.0
                    
                    landmarks.append(landmarkMap)
                }
                landmarkArray.append(landmarks)
            }
        }
        return landmarkArray
    }
}
