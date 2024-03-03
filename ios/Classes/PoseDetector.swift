//
//  PoseDetector.swift
//  google_mediapipe_pose_detection
//
//  Manages reading frames and sending back landmark data using Mediapipe.
//
//  Created by William Parker
//

import Foundation
import Flutter
import MediaPipeTasksVision


/// Main class of the library. Does all the work to convert the frames recived from Flutter into landmark data.
public class PoseDetector: NSObject, FlutterPlugin, FlutterStreamHandler
{
    
    /// A callback to respond with landmark data.
    var eventSink: FlutterEventSink?
    
    /// The Mediapipe Landmarker object to detect landmark data in camera frames.
    var poseLandmarker: PoseLandmarker?
    
    /// A buffer to hold the most recent image. Useful for if the `poseLandmarker` is still working on the previous image.
    var savedImage: MPImage?
    
    /// Flag for if the pose detector is currently working on proccessing an image into landmark data.
    var isWorking = false
    
    
    /// Regiesters the plugin with Flutter. Like an init function, creates a `PoseDetector` object for Flutter to use.
    /// and starts a thread for the object to detect images indefinitly.
    /// - Parameter registrar: Provides the plugin access to contextual information and register callbacks for various application events.
    public static func register(with registrar: FlutterPluginRegistrar)
    {
        let poseDetector = PoseDetector()
        
        let methodChannel = FlutterMethodChannel(name: "google_mediapipe_pose_detection", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(poseDetector, channel: methodChannel)
        
        let eventChannel = FlutterEventChannel(name: "google_mediapipe_pose_detection_results", binaryMessenger: registrar.messenger())
        eventChannel.setStreamHandler(poseDetector)
        
        DispatchQueue.global().async
        {
            while(true)
            {
                poseDetector.detectSavedImage()
            }
        }
    }
    
    /// Handles incoming calls from Flutter.
    /// - Parameters:
    ///   - call: The method and data it wants to activate.
    ///   - result: A `FlutterResult` to send error messages back to Flutter.
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult)
    {
        switch call.method
        {
        case "startPoseDetector":
            handleDetection(call: call, result: result)
        case "closePoseDetector":
            result(nil)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    /// Takes the image data and converts it to the landmark data. Creates a PoseLandmarker if needed.
    /// - Parameters:
    ///   - call: The data Flutter sends about how the request should be interpeted.
    ///   - result: A `FlutterResult` to send error messages back to Flutter.
    public func handleDetection(call: FlutterMethodCall, result: @escaping FlutterResult)
    {
        guard let args = call.arguments as? [String: Any],
              let imageData = args["imageData"] as? [String: Any],
              let mpImage = InputImageConverter.visionImage(from: imageData, result: result),
              let options = args["options"] as? [String: Any],
              let mode = options["mode"] as? String
        else
        {
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
                
                let landmarkResult: [[[String: Any]]] = PoseDetector.convertPoseData(poseLandmarkerResult: detectionResult)
                
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
    
    /// Attempts to send a new image to the `poseLandmarker` for processing.
    public func detectSavedImage()
    {
        if !isWorking && savedImage != nil
        {
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
    
    /// Tries to create a new `PoseLandmarker` to use for detection.
    /// - Parameters:
    ///   - options: A dictionary defining how the `PoseLandmarker` should be created.
    ///   - result: A `FlutterResult` to send error messages back to Flutter.
    public func setupPoseLandmarker(options: [String: Any], result: @escaping FlutterResult)
    {
        guard let model = options["model"] as? String,
              let minPoseDetectionConfidence = options["minPoseDetectionConfidence"] as? Double,
              let minPosePresenceConfidence = options["minPosePresenceConfidence"] as? Double,
              let minPoseTrackingConfidence = options["minTrackingConfidence"] as? Double,
              let numPoses = options["numPoses"] as? Int,
              let mode = options["mode"] as? String
        else
        {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
            return
        }
        
        var modelPath = "assets/"
        
        switch model
        {
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
        options.numPoses = numPoses
        
        if mode == "liveStream"
        {
            options.runningMode = .liveStream
            let processor = self
            options.poseLandmarkerLiveStreamDelegate = processor
        }
        else if mode == "image"
        {
            options.runningMode = .image
        }
        
        do
        {
            poseLandmarker = try PoseLandmarker(options: options)
        }
        catch
        {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Failed to create poseLandmarker", details: nil))
        }
    }
    
    /// Method for `FlutterStreamHandler` to link the stream to the object on startup.
    /// - Parameters:
    ///   - arguments: Unused.
    ///   - events: Provides a link from Flutter to Swift.
    /// - Returns: Always returns `nil` as no error can occur.
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError?
    {
        eventSink = events
        return nil
    }
    
    /// Method for `FlutterStreamHandler` to unlink the stream to the object on teardown.
    /// - Parameter arguments: Unused.
    /// - Returns: Always returns `nil` as no error can occur.
    public func onCancel(withArguments arguments: Any?) -> FlutterError?
    {
        eventSink = nil
        return nil
    }
    
    /// Converts the poses returned from the `PoseLandmarker` to a array of dictionarys of landmark variables to be sent to Flutter.
    /// - Parameter poseLandmarkerResult: The pose returned from `PoseLandmarker`.
    /// - Returns: A 3D structure that can be sent back to Flutter. First a list with each pose (useful if `numPoses` is more then `1`), then holds
    /// a map for each landmark in the pose. Finally, each landmark is a map of variables describing the landmark.
    public static func convertPoseData(poseLandmarkerResult: PoseLandmarkerResult) -> [[[String: Any]]]
    {
        var landmarkArray: [[Dictionary<String, Any>]] = []
        
        if !poseLandmarkerResult.landmarks.isEmpty
        {
            for pose in poseLandmarkerResult.landmarks
            {
                var landmarks: [Dictionary<String, Any>] = []
                
                for (index, landmark) in pose.enumerated()
                {
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

/// Provides the class with the ability to interpret poses from the `PoseLandmarker`.
extension PoseDetector: PoseLandmarkerLiveStreamDelegate
{
    
    /// A method that the pose landmarker calls once it finishes performing
    /// landmarks detection in each input frame. Do not use directly.
    /// - Parameters:
    ///   - poseLandmarker: The object that detected the pose.
    ///   - result: the object representing the pose in frame.
    ///   - timestampInMilliseconds: A time value representing the detection.
    ///   - error: `nil` unless a detection failed.
    public func poseLandmarker(
        _ poseLandmarker: PoseLandmarker,
        didFinishDetection result: PoseLandmarkerResult?,
        timestampInMilliseconds: Int,
        error: Error?)
    {
        if error != nil
        {
            print(error?.localizedDescription ?? "Unkown Error")
            return
        }
        
        isWorking = false
        
        if result != nil
        {
            let landmarkList: [[[String: Any]]] = PoseDetector.convertPoseData(poseLandmarkerResult: result!)
            
            DispatchQueue.main.async
            {
                self.eventSink?(landmarkList)
            }
        }
    }
}
