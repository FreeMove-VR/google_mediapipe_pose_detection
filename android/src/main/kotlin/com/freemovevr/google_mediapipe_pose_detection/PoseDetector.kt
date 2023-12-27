package com.freemovevr.google_mediapipe_pose_detection

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import com.google.mediapipe.framework.image.MPImage
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.core.Delegate
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarker
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarkerResult
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import org.jetbrains.annotations.NotNull


class PoseDetector(
    private val context: Context,
    private val flutterPluginBinding: FlutterPlugin.FlutterPluginBinding
) : MethodCallHandler, EventChannel.StreamHandler {

    private var eventSink: EventChannel.EventSink? = null

    private var poseLandmarker: PoseLandmarker? = null

    private var isWorking = false

    private var landmarkArrayHolder: MutableList<List<Map<String, Any>>>? = null

    private var frameCount = 0
    private var frameTimer = 0L

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            START -> handleDetection(call, result)
            READ -> readResult(result)
            CLOSE -> {
                closeDetector()
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    private fun readResult(result: MethodChannel.Result) {
        val landmarkArray = landmarkArrayHolder

        landmarkArrayHolder = null

        result.success(landmarkArray)
    }

    private fun handleDetection(call: MethodCall, result: MethodChannel.Result) {
        val imageData = call.argument<Any>("imageData") as Map<*, *>
        val inputImage: MPImage = getInputImageFromData(
            imageData,
            result
        ) ?: return

        if (isWorking) {
            result.success(null)
            return
        }

        val options = call.argument<Map<String, Any>>("options")
        if (options == null) {
            result.error("PoseDetectorError", "Invalid options", null)
            return
        }
        // If pose detector is null, try to set it up
        poseLandmarker = poseLandmarker ?: setupPoseLandmarker(options)

        // If it is still null, we cannot detect the poses
        if (poseLandmarker == null) {
            result.error("PoseDetectorError", "Could not make landmarker", null)
            return
        }

        isWorking = true
        when (options["mode"] as String?) {
            RUNNING_MODE_IMAGE -> {
                poseLandmarker?.detect(inputImage)?.also { landmarkResult ->
                    sendPoseData(landmarkResult)
                }
            }

            RUNNING_MODE_LIVESTREAM -> {
                val frameTime = SystemClock.uptimeMillis()

                poseLandmarker!!.detectAsync(inputImage, frameTime)
            }
        }
        result.success(null)
    }

    private fun setupPoseLandmarker(options: Map<String, Any>): PoseLandmarker? {
        // Set general pose landmarker options
        val baseOptionBuilder = BaseOptions.builder()

        // Use the specified hardware for running the model. Default to CPU
        when (options["delegate"] as String?) {
            DELEGATE_CPU -> {
                baseOptionBuilder.setDelegate(Delegate.CPU)
            }

            DELEGATE_GPU -> {
                baseOptionBuilder.setDelegate(Delegate.GPU)
            }
        }

        val modelName = "assets/" +
                when (options["model"] as String?) {
                    MODEL_POSE_LANDMARKER_FULL -> "pose_landmarker_full.task"
                    MODEL_POSE_LANDMARKER_LITE -> "pose_landmarker_lite.task"
                    MODEL_POSE_LANDMARKER_HEAVY -> "pose_landmarker_heavy.task"
                    else -> "pose_landmarker_full.task"
                }

        val assetPath: String = flutterPluginBinding
            .flutterAssets
            .getAssetFilePathBySubpath(modelName, "google_mediapipe_pose_detection")

        baseOptionBuilder.setModelAssetPath(assetPath)

        try {
            val baseOptions = baseOptionBuilder.build()
            // Create an option builder with base options and specific
            // options only use for Pose Landmarker.
            val optionsBuilder =
                PoseLandmarker.PoseLandmarkerOptions.builder()
                    .setBaseOptions(baseOptions)
                    .setMinPoseDetectionConfidence((options["minPoseDetectionConfidence"] as Double).toFloat())
                    .setMinTrackingConfidence((options["minTrackingConfidence"] as Double).toFloat())
                    .setMinPosePresenceConfidence((options["minPosePresenceConfidence"] as Double).toFloat())

            val runningMode = options["mode"] as String?

            when (runningMode) {
                RUNNING_MODE_IMAGE -> {
                    optionsBuilder.setRunningMode(RunningMode.IMAGE)
                }

                RUNNING_MODE_LIVESTREAM -> {
                    optionsBuilder.setRunningMode(RunningMode.LIVE_STREAM)
                }
            }

            // The ResultListener and ErrorListener only use for LIVE_STREAM mode.
            if (runningMode == RUNNING_MODE_LIVESTREAM) {
                optionsBuilder
                    .setResultListener(this::returnLivestreamResult)
                    .setErrorListener(this::returnLivestreamError)
            }

            val modelOptions = optionsBuilder.build()
            poseLandmarker =
                PoseLandmarker.createFromOptions(context, modelOptions)

            return poseLandmarker

        } catch (e: IllegalStateException) {
            Log.e(
                TAG,
                "Pose Landmarker failed to initialize. See error logs for details"
            )
            Log.e(
                TAG, "MediaPipe failed to load the task with error: " + e.message
            )
        } catch (e: RuntimeException) {
            // This occurs if the model being used does not support GPU
            Log.e(
                TAG,
                "Pose Landmarker failed to initialize. This occurs if the model being used " +
                        "does not support GPU."
            )
            Log.e(
                TAG,
                "Image classifier failed to load model with error: " + e.message
            )
        }
        return null
    }

    // Return the landmark result to this PoseLandmarkerHelper's caller
    private fun returnLivestreamResult(
        result: PoseLandmarkerResult,
        image: MPImage
    ) {
        sendPoseData(result)
    }

    // Return errors thrown during detection to this PoseLandmarkerHelper's
    // caller
    private fun returnLivestreamError(error: RuntimeException) {
        Log.e(
            TAG,
            error.message ?: "An unknown error has occurred"
        )
    }

    private fun sendPoseData(poseLandmarkerResult: PoseLandmarkerResult) {

        val landmarkArray: MutableList<List<Map<String, Any>>> =
            ArrayList()
        if (poseLandmarkerResult.landmarks().isNotEmpty()) {
            for (pose in poseLandmarkerResult.landmarks()) {
                val landmarks: MutableList<Map<String, Any>> =
                    ArrayList()
                for ((index, landmark) in pose.withIndex()) {
                    val landmarkMap: MutableMap<String, Any> =
                        HashMap()
                    landmarkMap["type"] = index
                    landmarkMap["x"] = landmark.x()
                    landmarkMap["y"] = landmark.y()
                    landmarkMap["z"] = landmark.z()
                    landmarkMap["presence"] = landmark.presence().orElse(0.0F)
                    landmarkMap["visibility"] = landmark.visibility().orElse(0.0F)
                    landmarks.add(landmarkMap)
                }
                landmarkArray.add(landmarks)
            }
        }

        isWorking = false
        landmarkArrayHolder = landmarkArray
    }

    private fun closeDetector() {
        poseLandmarker?.close()
    }

    companion object {
        const val TAG = "google_mediapipe_pose_detection"
        private const val START = "startPoseDetector"
        private const val READ = "readPoseDetection"
        private const val CLOSE = "closePoseDetector"

        const val DELEGATE_CPU = "CPU"
        const val DELEGATE_GPU = "GPU"
        const val RUNNING_MODE_IMAGE = "image"
        const val RUNNING_MODE_LIVESTREAM = "liveStream"
        const val MODEL_POSE_LANDMARKER_FULL = "full"
        const val MODEL_POSE_LANDMARKER_LITE = "lite"
        const val MODEL_POSE_LANDMARKER_HEAVY = "heavy"
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }
}