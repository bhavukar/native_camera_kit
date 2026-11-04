package dev.bhavuk.native_camera_kit

import android.content.Context
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.os.Build
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.view.TextureRegistry

class NativeCameraKitPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var methodChannel: MethodChannel
    private lateinit var textureRegistry: TextureRegistry
    private lateinit var cameraManager: CameraManager
    private lateinit var context: Context
    private lateinit var binaryMessenger: BinaryMessenger

    private val sessions = mutableMapOf<Long, NativeCameraSession>()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        textureRegistry = binding.textureRegistry
        binaryMessenger = binding.binaryMessenger
        cameraManager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager

        methodChannel = MethodChannel(binding.binaryMessenger, "dev.bhavuk.native_camera_kit")
        methodChannel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "availableCameras" -> handleAvailableCameras(result)
            "create" -> handleCreate(call, result)
            "initialize" -> {
                val textureId = (call.argument<Number>("textureId"))?.toLong()
                val session = sessions[textureId]
                if (session != null) {
                    session.initialize(result)
                } else {
                    result.error("INVALID_TEXTURE_ID", "No camera session for textureId $textureId", null)
                }
            }
            "dispose" -> {
                val textureId = (call.argument<Number>("textureId"))?.toLong()
                val session = sessions.remove(textureId)
                session?.dispose()
                result.success(null)
            }
            "takePicture" -> {
                val textureId = (call.argument<Number>("textureId"))?.toLong()
                val path = call.argument<String>("path")
                val session = sessions[textureId]
                if (session != null) {
                    session.takePicture(path, result)
                } else {
                    result.error("INVALID_TEXTURE_ID", "No session found", null)
                }
            }
            "startVideoRecording" -> {
                val textureId = (call.argument<Number>("textureId"))?.toLong()
                val path = call.argument<String>("path")
                val session = sessions[textureId]
                if (session != null) {
                    session.startVideoRecording(path, result)
                } else {
                    result.error("INVALID_TEXTURE_ID", "No session found", null)
                }
            }
            "pauseVideoRecording" -> {
                val textureId = (call.argument<Number>("textureId"))?.toLong()
                sessions[textureId]?.pauseVideoRecording(result) ?: result.error("INVALID_ID", "Not found", null)
            }
            "resumeVideoRecording" -> {
                val textureId = (call.argument<Number>("textureId"))?.toLong()
                sessions[textureId]?.resumeVideoRecording(result) ?: result.error("INVALID_ID", "Not found", null)
            }
            "stopVideoRecording" -> {
                val textureId = (call.argument<Number>("textureId"))?.toLong()
                sessions[textureId]?.stopVideoRecording(result) ?: result.error("INVALID_ID", "Not found", null)
            }
            "setFlashMode" -> {
                val textureId = (call.argument<Number>("textureId"))?.toLong()
                val mode = call.argument<String>("mode") ?: "auto"
                sessions[textureId]?.setFlashMode(mode, result) ?: result.error("INVALID_ID", "Not found", null)
            }
            "setTorchMode" -> {
                val textureId = (call.argument<Number>("textureId"))?.toLong()
                val enabled = call.argument<Boolean>("enabled") ?: false
                sessions[textureId]?.setTorchMode(enabled, result) ?: result.error("INVALID_ID", "Not found", null)
            }
            "setFocusMode" -> {
                val textureId = (call.argument<Number>("textureId"))?.toLong()
                val mode = call.argument<String>("mode") ?: "auto"
                sessions[textureId]?.setFocusMode(mode, result) ?: result.error("INVALID_ID", "Not found", null)
            }
            "setFocusDistance" -> {
                val textureId = (call.argument<Number>("textureId"))?.toLong()
                val distance = (call.argument<Number>("distance"))?.toFloat() ?: 0.0f
                sessions[textureId]?.setFocusDistance(distance, result) ?: result.error("INVALID_ID", "Not found", null)
            }
            "setPointOfInterest" -> {
                val textureId = (call.argument<Number>("textureId"))?.toLong()
                val x = (call.argument<Number>("x"))?.toDouble() ?: 0.5
                val y = (call.argument<Number>("y"))?.toDouble() ?: 0.5
                sessions[textureId]?.setPointOfInterest(x, y, result) ?: result.error("INVALID_ID", "Not found", null)
            }
            "setExposureMode" -> {
                val textureId = (call.argument<Number>("textureId"))?.toLong()
                val mode = call.argument<String>("mode") ?: "auto"
                sessions[textureId]?.setExposureMode(mode, result) ?: result.error("INVALID_ID", "Not found", null)
            }
            "setIso" -> {
                val textureId = (call.argument<Number>("textureId"))?.toLong()
                val iso = (call.argument<Number>("iso"))?.toInt() ?: 100
                sessions[textureId]?.setIso(iso, result) ?: result.error("INVALID_ID", "Not found", null)
            }
            "setExposureDuration" -> {
                val textureId = (call.argument<Number>("textureId"))?.toLong()
                val durationMicros = (call.argument<Number>("durationMicros"))?.toLong() ?: 10000L
                sessions[textureId]?.setExposureDuration(durationMicros, result) ?: result.error("INVALID_ID", "Not found", null)
            }
            "setExposureBias" -> {
                val textureId = (call.argument<Number>("textureId"))?.toLong()
                val bias = (call.argument<Number>("bias"))?.toDouble() ?: 0.0
                sessions[textureId]?.setExposureBias(bias, result) ?: result.error("INVALID_ID", "Not found", null)
            }
            "setWhiteBalanceMode" -> {
                val textureId = (call.argument<Number>("textureId"))?.toLong()
                val mode = call.argument<String>("mode") ?: "auto"
                sessions[textureId]?.setWhiteBalanceMode(mode, result) ?: result.error("INVALID_ID", "Not found", null)
            }
            "setZoom" -> {
                val textureId = (call.argument<Number>("textureId"))?.toLong()
                val zoom = (call.argument<Number>("zoom"))?.toFloat() ?: 1.0f
                sessions[textureId]?.setZoom(zoom, result) ?: result.error("INVALID_ID", "Not found", null)
            }
            "setFps" -> {
                val textureId = (call.argument<Number>("textureId"))?.toLong()
                val fps = (call.argument<Number>("fps"))?.toInt() ?: 30
                sessions[textureId]?.setFps(fps, result) ?: result.error("INVALID_ID", "Not found", null)
            }
            "setStabilizationMode" -> {
                val textureId = (call.argument<Number>("textureId"))?.toLong()
                val mode = call.argument<String>("mode") ?: "auto"
                sessions[textureId]?.setStabilizationMode(mode, result) ?: result.error("INVALID_ID", "Not found", null)
            }
            "stopImageStream" -> {
                val textureId = (call.argument<Number>("textureId"))?.toLong()
                sessions[textureId]?.stopImageStream(result) ?: result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun handleAvailableCameras(result: Result) {
        try {
            val cameraIds = cameraManager.cameraIdList
            val cameras = mutableListOf<Map<String, Any?>>()

            for (id in cameraIds) {
                val characteristics = cameraManager.getCameraCharacteristics(id)
                val facing = characteristics.get(CameraCharacteristics.LENS_FACING)
                val position = when (facing) {
                    CameraCharacteristics.LENS_FACING_FRONT -> "front"
                    CameraCharacteristics.LENS_FACING_EXTERNAL -> "external"
                    else -> "back"
                }

                val orientation = characteristics.get(CameraCharacteristics.SENSOR_ORIENTATION) ?: 90
                val isoRange = characteristics.get(CameraCharacteristics.SENSOR_INFO_SENSITIVITY_RANGE)
                val exposureRange = characteristics.get(CameraCharacteristics.SENSOR_INFO_EXPOSURE_TIME_RANGE)
                val minFocusDistance = 0.0
                val maxFocusDistance = (characteristics.get(CameraCharacteristics.LENS_INFO_MINIMUM_FOCUS_DISTANCE) ?: 10.0f).toDouble()

                val maxZoom = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    val range = characteristics.get(CameraCharacteristics.CONTROL_ZOOM_RATIO_RANGE)
                    (range?.upper ?: 10.0f).toDouble()
                } else {
                    (characteristics.get(CameraCharacteristics.SCALER_AVAILABLE_MAX_DIGITAL_ZOOM) ?: 10.0f).toDouble()
                }

                val compensationRange = characteristics.get(CameraCharacteristics.CONTROL_AE_COMPENSATION_RANGE)
                val compensationStep = characteristics.get(CameraCharacteristics.CONTROL_AE_COMPENSATION_STEP)?.toFloat() ?: 0.333f

                val fpsRanges = characteristics.get(CameraCharacteristics.CONTROL_AE_AVAILABLE_TARGET_FPS_RANGES) ?: emptyArray()
                val fpsList = fpsRanges.map { mapOf("min" to it.lower, "max" to it.upper) }

                val flashAvailable = characteristics.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) ?: false

                cameras.add(
                    mapOf(
                        "id" to id,
                        "name" to "Camera $id ($position)",
                        "position" to position,
                        "sensorOrientation" to orientation,
                        "minIso" to (isoRange?.lower ?: 50),
                        "maxIso" to (isoRange?.upper ?: 3200),
                        "minExposureDurationMicros" to ((exposureRange?.lower ?: 100000L) / 1000L),
                        "maxExposureDurationMicros" to ((exposureRange?.upper ?: 1000000000L) / 1000L),
                        "minFocusDistance" to minFocusDistance,
                        "maxFocusDistance" to maxFocusDistance,
                        "minZoom" to 1.0,
                        "maxZoom" to maxZoom,
                        "minExposureBias" to ((compensationRange?.lower ?: -6) * compensationStep),
                        "maxExposureBias" to ((compensationRange?.upper ?: 6) * compensationStep),
                        "exposureBiasStep" to compensationStep.toDouble(),
                        "supportedFpsRanges" to fpsList,
                        "supportsFlash" to flashAvailable,
                        "supportsTorch" to flashAvailable,
                        "supportsManualFocus" to (maxFocusDistance > 0.0),
                        "supportsManualExposure" to (isoRange != null && exposureRange != null)
                    )
                )
            }

            result.success(cameras)
        } catch (e: Exception) {
            result.error("CAMERAS_FETCH_ERROR", e.localizedMessage, null)
        }
    }

    private fun handleCreate(call: MethodCall, result: Result) {
        try {
            val cameraId = call.argument<String>("cameraId") ?: "0"
            val resolutionPreset = call.argument<String>("resolutionPreset") ?: "veryHigh"
            val enableAudio = call.argument<Boolean>("enableAudio") ?: true
            val imageFormatGroup = call.argument<String>("imageFormatGroup") ?: "yuv420"

            val surfaceEntry = textureRegistry.createSurfaceTexture()
            val textureId = surfaceEntry.id()

            val session = NativeCameraSession(
                context = context,
                cameraManager = cameraManager,
                cameraId = cameraId,
                resolutionPreset = resolutionPreset,
                enableAudio = enableAudio,
                imageFormatGroup = imageFormatGroup,
                surfaceEntry = surfaceEntry,
                binaryMessenger = binaryMessenger
            )

            // Setup image streaming EventChannel for this textureId
            val eventChannel = EventChannel(binaryMessenger, "dev.bhavuk.native_camera_kit/image_stream_$textureId")
            eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    if (events != null) {
                        session.setupImageStream(events)
                    }
                }

                override fun onCancel(arguments: Any?) {
                    // Handled internally in session
                }
            })

            sessions[textureId] = session

            result.success(
                mapOf(
                    "textureId" to textureId,
                    "previewWidth" to session.previewWidth,
                    "previewHeight" to session.previewHeight
                )
            )
        } catch (e: Exception) {
            result.error("CREATE_CAMERA_ERROR", e.localizedMessage, null)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        sessions.values.forEach { it.dispose() }
        sessions.clear()
    }
}
