//
//  GoogleMediapipePoseDetection.swift
//  google_mediapipe_pose_detection
//
//  This file provides access to the library from Flutter.
//
//  Created by William Parker
//

import Flutter
import UIKit


/// Entry point class for the plugin.
public class GoogleMediapipePoseDetectionPlugin: NSObject, FlutterPlugin
{
    
    /// Provies an entry point to use the pose detector plugin.
    /// - Parameter registrar: Flutter's internal register for the plugin.
    public static func register(with registrar: FlutterPluginRegistrar)
    {
        PoseDetector.register(with: registrar)
    }
}
