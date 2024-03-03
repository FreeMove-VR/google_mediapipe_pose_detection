//
//  InputImageConverter.swift
//  google_mediapipe_pose_detection
//
//  Converts the image to mediapipe's file format.
//
//  Created by William Parker
//

import Foundation
import MediaPipeTasksVision
import Flutter


/// Class to handle the conversion from Flutter's image to the Mediapipe `MPImage`.
class InputImageConverter
{
    /// An image from Flutter will be sent as a `imageData`, this containes the type of image and the data of the image depending on the type.
    /// This function converts any type of image recived into an `MPImage` for Mediapipe to handle.
    /// - Parameters:
    ///   - imageData: The message sent on the Flutter side containing how the image should be interpreted and the data of the image.
    ///   - result: A `FlutterResult` to send error messages back to Flutter.
    /// - Returns: The image as a Mediapipe `MPImage` to be interpreted by the landmarker. It will return `nil` if `imageData["type"]`
    /// is an unexpected value or the image could not be created. In these cases, `result` will be used to return the error to Flutter.
    static func visionImage(from imageData: [String: Any], result: @escaping FlutterResult) -> MPImage?
    {
        if let imageType = imageData["type"] as? String
        {
            if imageType == "file"
            {
                return filePathToVisionImage(filePath: imageData["path"] as? String ?? "", result: result)
            }
            else if imageType == "bytes"
            {
                guard let byteData = imageData["bytes"] as? FlutterStandardTypedData,
                      let metadata = imageData["metadata"] as? [String: Any]
                else
                {
                    result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing byte data", details: nil))
                    return nil
                }
                return bytesToVisionImage(byteData: byteData, metadata: metadata, result: result)
            } else
            {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "No image type for: \(imageType)", details: nil))
            }
        }
        result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid image data", details: nil))
        return nil
    }
    
    /// Converts and image from the file path specified to a MPImage.
    /// - Parameters:
    ///   - filePath: The path of the image.
    ///   - result: A `FlutterResult` to send error messages back to Flutter.
    /// - Returns: The image as a Mediapipe `MPImage` to be interpreted by the landmarker. It will return `nil` if the path is invalid
    /// or the image found cannot be made into a `MPImage`. In these cases, `result` will be used to return the error to Flutter.
    static func filePathToVisionImage(filePath: String, result: @escaping FlutterResult) -> MPImage?
    {
        if let image = UIImage(contentsOfFile: filePath)
        {
            do
            {
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
    
    /// Converts the byte array image to a MPImage if possible.
    /// - Parameters:
    ///   - byteData: The Binary representation of the image.
    ///   - metadata: Defines how the image should be reconstructed.
    ///   - result: A `FlutterResult` to send error messages back to Flutter.
    /// - Returns: The image as a Mediapipe `MPImage` to be interpreted by the landmarker. It will return `nil` if metadata
    /// contains missing data or the image could not be created. In these cases, `result` will be used to return the error to Flutter.
    static func bytesToVisionImage(byteData: FlutterStandardTypedData, metadata: [String: Any], result: @escaping FlutterResult) -> MPImage?
    {
        guard let width = metadata["width"] as? NSNumber,
              let height = metadata["height"] as? NSNumber,
              let rawFormat = metadata["image_format"] as? NSNumber,
              let bytesPerRow = metadata["bytes_per_row"] as? NSNumber
        else
        {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing or invalid image metadata", details: nil))
            return nil
        }
        
        let imageBytes = byteData.data
        
        let pxBuffer = bytesToPixelBuffer(width: width.uintValue,
                                          height: height.uintValue,
                                          format: UInt32(rawFormat.uintValue),
                                          baseAddress: UnsafeMutableRawPointer(mutating: (imageBytes as NSData).bytes),
                                          bytesPerRow: bytesPerRow.uintValue)
        
        guard let mpImage = pixelBufferToVisionImage(pxBuffer, result: result)
        else
        {
            return nil
        }
        return mpImage
    }
    
    /// Converts a pointer to the image bytes to a`CVPixelBuffer`.
    /// - Parameters:
    ///   - width: The width in pixels of the image.
    ///   - height: The height in pixels of the image.
    ///   - format: The pixel format identified by its respective four character code (type OSType).
    ///   - baseAddress: A pointer to the base address of the memory storing the pixels.
    ///   - bytesPerRow: The row bytes of the pixel storage memory.
    /// - Returns: The pixel buffer representation of the image.
    static func bytesToPixelBuffer(width: UInt,
                                   height: UInt,
                                   format: UInt32,
                                   baseAddress: UnsafeMutableRawPointer,
                                   bytesPerRow: UInt) -> CVPixelBuffer
    {
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
    
    /// Converts the pixel buffer into Mediapipe's image format.
    /// - Parameters:
    ///   - pixelBufferRef: The pixel buffer representation of the image.
    ///   - result: A `FlutterResult` to send error messages back to Flutter.
    /// - Returns: The image as a Mediapipe `MPImage` to be interpreted by the landmarker. It will return 
    /// `nil` if the image could not be created. In these cases, `result` will be used to return the error to Flutter.
    static func pixelBufferToVisionImage(_ pixelBufferRef: CVPixelBuffer, result: @escaping FlutterResult) -> MPImage?
    {
        let ciImage = CIImage(cvPixelBuffer: pixelBufferRef)
        
        let temporaryContext = CIContext(options: nil)
        guard let videoImage = temporaryContext.createCGImage(ciImage,
                                                              from: CGRect(x: 0,
                                                                           y: 0,
                                                                           width: CVPixelBufferGetWidth(pixelBufferRef),
                                                                           height: CVPixelBufferGetHeight(pixelBufferRef)))
        else
        {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Failed to create CGImage from CIImage", details: nil))
            return nil
        }
        let uiImage = UIImage(cgImage: videoImage)
        do
        {
            let visionImage = try MPImage(uiImage: uiImage)
            return visionImage
        }
        catch
        {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Could not create MPImage from data", details: nil))
            return nil
        }
    }
}
