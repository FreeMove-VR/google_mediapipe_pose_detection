//
//  InputImageConverter.swift
//  google_mediapipe_pose_detection
//
//  Created by William Parker on 29/12/2023.
//

import Foundation
import MediaPipeTasksVision
import Flutter

class InputImageConverter {
    static func visionImage(from imageData: [String: Any], result: @escaping FlutterResult) -> MPImage? {
        if let imageType = imageData["type"] as? String {
            if imageType == "file" {
                return filePathToVisionImage(imageData["path"] as? String ?? "", result: result)
            } else if imageType == "bytes" {
                return bytesToVisionImage(imageData, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "No image type for: \(imageType)", details: nil))
            }
        }
        result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid image data", details: nil))
        return nil
    }
    
    static func filePathToVisionImage(_ filePath: String, result: @escaping FlutterResult) -> MPImage? {
        if let image = UIImage(contentsOfFile: filePath) {
            do {
                let visionImage = try MPImage(uiImage: image, orientation: image.imageOrientation)
                return visionImage
            }
            catch
            {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Could not create MPImage from data", details: nil))
            }
        }
        result(FlutterError(code: "INVALID_ARGUMENTS", message: "Failed to create image from file path", details: nil))
        return nil
    }
    
    static func bytesToVisionImage(_ imageData: [String: Any], result: @escaping FlutterResult) -> MPImage? {
        guard let byteData = imageData["bytes"] as? FlutterStandardTypedData else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing byte data", details: nil))
            return nil
        }
        let imageBytes = byteData.data
        guard let metadata = imageData["metadata"] as? [String: Any],
              let width = metadata["width"] as? NSNumber,
              let height = metadata["height"] as? NSNumber,
              let rawFormat = metadata["image_format"] as? NSNumber,
              let bytesPerRow = metadata["bytes_per_row"] as? NSNumber else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing or invalid image metadata", details: nil))
            return nil
        }
        
        let pxBuffer = bytesToPixelBuffer(width: width.uintValue,
                                          height: height.uintValue,
                                          format: UInt32(rawFormat.uintValue),
                                          baseAddress: UnsafeMutableRawPointer(mutating: (imageBytes as NSData).bytes),
                                          bytesPerRow: bytesPerRow.uintValue)
        return pixelBufferToVisionImage(pxBuffer, result: result)
    }
    
    static func bytesToPixelBuffer(width: UInt,
                                   height: UInt,
                                   format: UInt32,
                                   baseAddress: UnsafeMutableRawPointer,
                                   bytesPerRow: UInt) -> CVPixelBuffer {
        var pxBuffer: CVPixelBuffer?
        let _ = CVPixelBufferCreateWithBytes(kCFAllocatorDefault,
                                             Int(width),
                                             Int(height),
                                             format,
                                             baseAddress,
                                             Int(bytesPerRow),
                                             nil,
                                             nil,
                                             nil,
                                             &pxBuffer)
        return pxBuffer!
    }
    
    static func pixelBufferToVisionImage(_ pixelBufferRef: CVPixelBuffer, result: @escaping FlutterResult) -> MPImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBufferRef)
        
        let temporaryContext = CIContext(options: nil)
        if let videoImage = temporaryContext.createCGImage(ciImage,
                                                           from: CGRect(x: 0,
                                                                        y: 0,
                                                                        width: CVPixelBufferGetWidth(pixelBufferRef),
                                                                        height: CVPixelBufferGetHeight(pixelBufferRef))) {
            let uiImage = UIImage(cgImage: videoImage)
            do {
                let visionImage = try MPImage(uiImage: uiImage)
                return visionImage
            }
            catch
            {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Could not create MPImage from data", details: nil))
            }
        }
        result(FlutterError(code: "INVALID_ARGUMENTS", message: "Failed to create CGImage from CIImage", details: nil))
        return nil
    }
}
