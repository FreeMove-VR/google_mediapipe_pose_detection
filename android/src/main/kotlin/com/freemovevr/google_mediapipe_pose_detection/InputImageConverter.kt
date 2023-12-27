package com.freemovevr.google_mediapipe_pose_detection

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageFormat
import android.graphics.Matrix
import android.graphics.Rect
import android.graphics.YuvImage
import android.media.Image
import android.renderscript.Allocation
import android.renderscript.RenderScript
import android.renderscript.ScriptIntrinsicYuvToRGB
import android.util.Log
import com.freemovevr.google_mediapipe_pose_detection.PoseDetector.Companion.TAG
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.framework.image.ByteBufferImageBuilder
import com.google.mediapipe.framework.image.MPImage
import com.google.mediapipe.framework.image.MPImage.IMAGE_FORMAT_NV21
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer


//Returns an [InputImage] from the image data received
fun getInputImageFromData(
    imageData: Map<*, *>,
    result: MethodChannel.Result
): MPImage? {
    //Differentiates whether the image data is a path for a image file or contains image data in form of bytes
    val model = imageData["type"] as String?
    val inputImage: MPImage

    val metaData = imageData["metadata"] as Map<*, *>

    val yuvImage = YuvImage(
        imageData["bytes"] as ByteArray,
        ImageFormat.NV21,
        (metaData["width"] as Double).toInt(),
        (metaData["height"] as Double).toInt(),
        null
    )

    val outputStream = ByteArrayOutputStream()
    yuvImage.compressToJpeg(
        Rect(
            0, 0, (metaData["width"] as Double).toInt(),
            (metaData["height"] as Double).toInt(),
        ), 100, outputStream
    )

    val jpegData = outputStream.toByteArray()
    val imageBitmap = BitmapFactory.decodeByteArray(jpegData, 0, jpegData.size)

    return when (model) {
        "file" -> {
            inputImage = BitmapImageBuilder(imageBitmap).build()
            inputImage
        }

        "bytes" -> {
            val matrix = Matrix().apply {
                // Rotate the frame received from the camera to be in the same direction as it'll be shown
                postRotate((metaData["rotation"] as Int).toFloat())
            }

            val rotatedBitmap = Bitmap.createBitmap(
                imageBitmap, 0, 0, imageBitmap.width, imageBitmap.height,
                matrix, true
            )

            inputImage = BitmapImageBuilder(rotatedBitmap).build()

            inputImage
        }

        else -> {
            result.error("InputImageConverterError", "Invalid Input Image", null)
            null
        }
    }
}
