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


class PoseDetector(
    private val context: Context,
    private val flutterPluginBinding: FlutterPlugin.FlutterPluginBinding
) : MethodCallHandler, EventChannel.StreamHandler {

    // Event channel for sending live stream pose detection results back to Flutter
    private var eventSink: EventChannel.EventSink? = null

    // Mediapipe's Pose Landmark task object
    private var poseLandmarker: PoseLandmarker? = null

    // Internal check for if the poseLandmarker is currently processing an image
    private var isWorking = false

    // The next image for the landmarker to detect
    private var savedImage: MPImage? = null

    /**
     * Method for Flutter to interact with Kotlin by specifying what method it wants to invoke.
     *
     * @param call The contents received from Flutter
     * @param result To be used to return a value
     */
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            START -> handleDetection(call, result)
            CLOSE -> {
                closeDetector()
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    /**
     * Check if the landmarker has been created yet, and if not, create it.
     * If call specifies this detection as a single image, process the image.
     * If it is a live stream, save the image at savedImage for detectSavedImage() to process when
     * the landmarker is available. Override the existing savedImage if one already exists
     *
     *
     * @param call The contents received from Flutter
     * @param result To be used to return a value
     */
    private fun handleDetection(call: MethodCall, result: MethodChannel.Result) {

        // Convert the image now so we do not slow down detectSavedImage() and the detectionThread
        val imageData = call.argument<Any>("imageData") as Map<*, *>
        val inputImage: MPImage = getInputImageFromData(
            imageData,
            result
        ) ?: return

        // If pose detector is null, try to set it up
        val options = call.argument<Map<String, Any>>("options")
        if (options == null) {
            result.error("PoseDetectorError", "Invalid options", null)
            return
        }
        poseLandmarker = poseLandmarker ?: setupPoseLandmarker(options)

        // If it is still null, we cannot detect the poses
        if (poseLandmarker == null) {
            result.error("PoseDetectorError", "Could not make landmarker", null)
            return
        }

        when (options["mode"] as String?) {
            // If we are just processing one image, we can do that here and return the result
            RUNNING_MODE_IMAGE -> {
                isWorking = true
                poseLandmarker?.detect(inputImage)?.also { landmarkResult ->

                    val convertedLandmarkResult: MutableList<List<Map<String, Any>>> = convertPoseData(landmarkResult)

                    isWorking = false

                    result.success(convertedLandmarkResult)
                }
            }

            // If we have livestream data, just save the image for the detectionThread
            RUNNING_MODE_LIVESTREAM -> {

                savedImage = inputImage
            }
        }
        // We must always end by calling result.
        // If we have gotten here we do not need to do anything more,
        // so just return successfully with nothing.
        result.success(null)
    }

    /**
     * If the poseLandmarker is not currently processing an image, detect the current savedImage
     * and set savedImage to null
     */
    fun detectSavedImage()
    {
        if(!isWorking && savedImage != null)
        {
            isWorking = true

            val frameTime = SystemClock.uptimeMillis()
            poseLandmarker!!.detectAsync(savedImage, frameTime)
            savedImage = null
        }
    }

    /**
     * Attempts to set up a poseLandmarker with the settings provided.
     *
     * @param options a map of how to set up the pose landmarker
     */
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

    /**
     * The callback the poseLandmarker makes after
     * successfully processing an image from a livestream.
     * Required function for Mediapipe, SHOULD NOT be used directly.
     * Once called, the results are sent back to Flutter through the event channel.
     */
    private fun returnLivestreamResult(
        result: PoseLandmarkerResult,
        image: MPImage
    ) {
        isWorking = false

        val landmarkList: MutableList<List<Map<String, Any>>> = convertPoseData(result)

        // Flutter requires the event channel to be called on the UI thread
        Handler(Looper.getMainLooper()).post {
            eventSink?.success(landmarkList)
        }
    }

    /**
     * The callback the poseLandmarker makes after
     * unsuccessfully processing an image from a livestream.
     * Required function for Mediapipe, SHOULD NOT be used directly.
     * If we get an error, just try to log it.
     */
    private fun returnLivestreamError(error: RuntimeException) {
        Log.e(
            TAG,
            error.message ?: "An unknown error has occurred"
        )
    }

    /**
     * Takes in the results from the poseLandmarker,
     * and converts it to be readable for Flutter's supported platform channel data types
     */
    private fun convertPoseData(poseLandmarkerResult: PoseLandmarkerResult): MutableList<List<Map<String, Any>>> {

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
        return landmarkArray
    }

    /**
     * Cleanup function.
     */
    private fun closeDetector() {
        poseLandmarker?.close()
    }

    companion object {
        // Logging tag
        const val TAG = "google_mediapipe_pose_detection"

        // Calls Flutter can make to Android
        private const val START = "startPoseDetector"
        private const val CLOSE = "closePoseDetector"

        // Configuration options for the pose landmarker
        const val DELEGATE_CPU = "CPU"
        const val DELEGATE_GPU = "GPU"
        const val RUNNING_MODE_IMAGE = "image"
        const val RUNNING_MODE_LIVESTREAM = "liveStream"
        const val MODEL_POSE_LANDMARKER_FULL = "full"
        const val MODEL_POSE_LANDMARKER_LITE = "lite"
        const val MODEL_POSE_LANDMARKER_HEAVY = "heavy"
    }

    /**
     * Required method for StreamHandler.
     * Sets up the eventSink to be used in relaying pose detection results back to Flutter
     */
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    /**
     * Required method for StreamHandler.
     */
    override fun onCancel(arguments: Any?) {
        eventSink = null
    }
}