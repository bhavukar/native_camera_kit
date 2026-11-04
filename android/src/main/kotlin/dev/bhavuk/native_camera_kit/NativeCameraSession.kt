package dev.bhavuk.native_camera_kit

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.ImageFormat
import android.graphics.Rect
import android.graphics.SurfaceTexture
import android.hardware.camera2.*
import android.hardware.camera2.params.MeteringRectangle
import android.media.Image
import android.media.ImageReader
import android.media.MediaRecorder
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.util.Range
import android.util.Size
import android.view.Surface
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry
import java.io.File
import java.io.FileOutputStream
import java.nio.ByteBuffer

class NativeCameraSession(
    private val context: Context,
    private val cameraManager: CameraManager,
    val cameraId: String,
    val resolutionPreset: String,
    val enableAudio: Boolean,
    val imageFormatGroup: String,
    val surfaceEntry: TextureRegistry.SurfaceTextureEntry,
    val binaryMessenger: BinaryMessenger
) {
    val textureId: Long = surfaceEntry.id()
    private val characteristics: CameraCharacteristics = cameraManager.getCameraCharacteristics(cameraId)

    private var backgroundThread: HandlerThread? = null
    private var backgroundHandler: Handler? = null

    private var cameraDevice: CameraDevice? = null
    private var captureSession: CameraCaptureSession? = null
    private var previewRequestBuilder: CaptureRequest.Builder? = null

    private var previewSurface: Surface? = null
    private var photoReader: ImageReader? = null
    private var streamReader: ImageReader? = null
    private var mediaRecorder: MediaRecorder? = null

    private var currentVideoPath: String? = null
    private var isRecordingVideo = false
    private var isRecordingPaused = false

    private var imageStreamSink: EventChannel.EventSink? = null
    private var imageEventChannel: EventChannel? = null

    var previewWidth: Int = 1920
    var previewHeight: Int = 1080

    // Manual controls cache
    private var activeIso: Int? = null
    private var activeExposureDurationNs: Long? = null
    private var activeFocusDistance: Float? = null
    private var activeZoom: Float = 1.0f
    private var activeFlashMode: String = "auto"
    private var activeTorchEnabled: Boolean = false

    init {
        computePreviewSize()
    }

    private fun computePreviewSize() {
        val map = characteristics.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
        val sizes = map?.getOutputSizes(SurfaceTexture::class.java) ?: emptyArray()

        val targetWidth = when (resolutionPreset.lowercase()) {
            "low" -> 352
            "medium" -> 720
            "high" -> 1280
            "veryhigh" -> 1920
            "ultrahigh" -> 3840
            else -> 1920
        }

        val chosen = sizes.minByOrNull { Math.abs(it.width - targetWidth) } ?: Size(1920, 1080)
        previewWidth = chosen.width
        previewHeight = chosen.height

        surfaceEntry.surfaceTexture().setDefaultBufferSize(previewWidth, previewHeight)
    }

    private fun startBackgroundThread() {
        if (backgroundThread == null) {
            backgroundThread = HandlerThread("NativeCameraKitBg-$textureId").apply { start() }
            backgroundHandler = Handler(backgroundThread!!.looper)
        }
    }

    private fun stopBackgroundThread() {
        backgroundThread?.quitSafely()
        try {
            backgroundThread?.join()
        } catch (_: InterruptedException) {}
        backgroundThread = null
        backgroundHandler = null
    }

    @SuppressLint("MissingPermission")
    fun initialize(result: MethodChannel.Result) {
        startBackgroundThread()

        val photoMap = characteristics.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
        val jpegSizes = photoMap?.getOutputSizes(ImageFormat.JPEG) ?: emptyArray()
        val maxJpegSize = jpegSizes.maxByOrNull { it.width * it.height } ?: Size(previewWidth, previewHeight)

        photoReader = ImageReader.newInstance(maxJpegSize.width, maxJpegSize.height, ImageFormat.JPEG, 2)

        try {
            cameraManager.openCamera(cameraId, object : CameraDevice.StateCallback() {
                override fun onOpened(camera: CameraDevice) {
                    cameraDevice = camera
                    startCaptureSession(result)
                }

                override fun onDisconnected(camera: CameraDevice) {
                    camera.close()
                    cameraDevice = null
                }

                override fun onError(camera: CameraDevice, error: Int) {
                    camera.close()
                    cameraDevice = null
                    postOnMain {
                        try {
                            result.error("CAMERA_ERROR", "Failed to open camera: code $error", null)
                        } catch (_: Exception) {}
                    }
                }
            }, backgroundHandler)
        } catch (e: Exception) {
            result.error("CAMERA_OPEN_FAILED", e.localizedMessage, null)
        }
    }

    private fun startCaptureSession(result: MethodChannel.Result? = null) {
        val device = cameraDevice ?: return
        val surfaceTexture = surfaceEntry.surfaceTexture()
        val surface = Surface(surfaceTexture)
        previewSurface = surface

        val surfaces = mutableListOf<Surface>(surface, photoReader!!.surface)

        if (streamReader != null) {
            surfaces.add(streamReader!!.surface)
        }

        try {
            val builder = device.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW)
            builder.addTarget(surface)
            previewRequestBuilder = builder

            // Setup default auto modes
            builder.set(CaptureRequest.CONTROL_MODE, CameraMetadata.CONTROL_MODE_AUTO)
            builder.set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE)
            builder.set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_ON)
            builder.set(CaptureRequest.CONTROL_AWB_MODE, CaptureRequest.CONTROL_AWB_MODE_AUTO)

            applyCachedSettings(builder)

            device.createCaptureSession(surfaces, object : CameraCaptureSession.StateCallback() {
                override fun onConfigured(session: CameraCaptureSession) {
                    captureSession = session
                    try {
                        session.setRepeatingRequest(builder.build(), null, backgroundHandler)
                        result?.let { postOnMain { it.success(null) } }
                    } catch (e: Exception) {
                        result?.let { postOnMain { it.error("SESSION_FAILED", e.localizedMessage, null) } }
                    }
                }

                override fun onConfigureFailed(session: CameraCaptureSession) {
                    result?.let { postOnMain { it.error("SESSION_CONFIG_FAILED", "Failed to configure capture session", null) } }
                }
            }, backgroundHandler)
        } catch (e: Exception) {
            result?.let { postOnMain { it.error("SESSION_EXCEPTION", e.localizedMessage, null) } }
        }
    }

    private fun applyCachedSettings(builder: CaptureRequest.Builder) {
        if (activeIso != null || activeExposureDurationNs != null) {
            builder.set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_OFF)
            activeIso?.let { builder.set(CaptureRequest.SENSOR_SENSITIVITY, it) }
            activeExposureDurationNs?.let { builder.set(CaptureRequest.SENSOR_EXPOSURE_TIME, it) }
        }

        activeFocusDistance?.let {
            builder.set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_OFF)
            builder.set(CaptureRequest.LENS_FOCUS_DISTANCE, it)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            builder.set(CaptureRequest.CONTROL_ZOOM_RATIO, activeZoom)
        } else {
            val sensorRect = characteristics.get(CameraCharacteristics.SENSOR_INFO_ACTIVE_ARRAY_SIZE)
            if (sensorRect != null) {
                val cropWidth = (sensorRect.width() / activeZoom).toInt()
                val cropHeight = (sensorRect.height() / activeZoom).toInt()
                val cropX = (sensorRect.width() - cropWidth) / 2
                val cropY = (sensorRect.height() - cropHeight) / 2
                builder.set(CaptureRequest.SCALER_CROP_REGION, Rect(cropX, cropY, cropX + cropWidth, cropY + cropHeight))
            }
        }

        if (activeTorchEnabled) {
            builder.set(CaptureRequest.FLASH_MODE, CaptureRequest.FLASH_MODE_TORCH)
        }
    }

    private fun updateRepeatingRequest() {
        val session = captureSession ?: return
        val builder = previewRequestBuilder ?: return
        try {
            session.setRepeatingRequest(builder.build(), null, backgroundHandler)
        } catch (_: Exception) {}
    }

    fun takePicture(targetPath: String?, result: MethodChannel.Result) {
        val device = cameraDevice ?: run {
            result.error("CAMERA_NOT_OPEN", "Camera is not opened", null)
            return
        }
        val session = captureSession ?: run {
            result.error("SESSION_NOT_OPEN", "Capture session not ready", null)
            return
        }
        val reader = photoReader ?: run {
            result.error("READER_NOT_READY", "Photo reader not configured", null)
            return
        }

        val outputFile = if (!targetPath.isNullOrEmpty()) {
            File(targetPath).apply { parentFile?.mkdirs() }
        } else {
            File.createTempFile("photo_${System.currentTimeMillis()}", ".jpg", context.cacheDir)
        }

        reader.setOnImageAvailableListener({ imgReader ->
            var image: Image? = null
            try {
                image = imgReader.acquireLatestImage()
                if (image != null) {
                    val buffer = image.planes[0].buffer
                    val bytes = ByteArray(buffer.remaining())
                    buffer.get(bytes)

                    FileOutputStream(outputFile).use { it.write(bytes) }

                    postOnMain {
                        result.success(
                            mapOf(
                                "path" to outputFile.absolutePath,
                                "width" to image.width,
                                "height" to image.height,
                                "bytesLength" to bytes.size,
                                "mimeType" to "image/jpeg"
                            )
                        )
                    }
                } else {
                    postOnMain { result.error("IMAGE_NULL", "Captured image was null", null) }
                }
            } catch (e: Exception) {
                postOnMain { result.error("PHOTO_SAVE_ERROR", e.localizedMessage, null) }
            } finally {
                image?.close()
            }
        }, backgroundHandler)

        try {
            val captureBuilder = device.createCaptureRequest(CameraDevice.TEMPLATE_STILL_CAPTURE)
            captureBuilder.addTarget(reader.surface)
            previewRequestBuilder?.let { p ->
                captureBuilder.set(CaptureRequest.CONTROL_MODE, p.get(CaptureRequest.CONTROL_MODE))
                captureBuilder.set(CaptureRequest.CONTROL_AF_MODE, p.get(CaptureRequest.CONTROL_AF_MODE))
                captureBuilder.set(CaptureRequest.CONTROL_AE_MODE, p.get(CaptureRequest.CONTROL_AE_MODE))
                captureBuilder.set(CaptureRequest.SENSOR_SENSITIVITY, p.get(CaptureRequest.SENSOR_SENSITIVITY))
                captureBuilder.set(CaptureRequest.SENSOR_EXPOSURE_TIME, p.get(CaptureRequest.SENSOR_EXPOSURE_TIME))
                captureBuilder.set(CaptureRequest.LENS_FOCUS_DISTANCE, p.get(CaptureRequest.LENS_FOCUS_DISTANCE))
            }

            session.capture(captureBuilder.build(), null, backgroundHandler)
        } catch (e: Exception) {
            result.error("CAPTURE_FAILED", e.localizedMessage, null)
        }
    }

    fun startVideoRecording(targetPath: String?, result: MethodChannel.Result) {
        val outputFile = if (!targetPath.isNullOrEmpty()) {
            File(targetPath).apply { parentFile?.mkdirs() }
        } else {
            File.createTempFile("video_${System.currentTimeMillis()}", ".mp4", context.cacheDir)
        }
        currentVideoPath = outputFile.absolutePath

        try {
            @Suppress("DEPRECATION")
            mediaRecorder = (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                MediaRecorder(context)
            } else {
                MediaRecorder()
            }).apply {
                if (enableAudio) {
                    setAudioSource(MediaRecorder.AudioSource.MIC)
                }
                setVideoSource(MediaRecorder.VideoSource.SURFACE)
                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                setOutputFile(outputFile.absolutePath)
                setVideoEncodingBitRate(10000000)
                setVideoFrameRate(30)
                setVideoSize(previewWidth, previewHeight)
                setVideoEncoder(MediaRecorder.VideoEncoder.H264)
                if (enableAudio) {
                    setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                }
                val sensorOrientation = characteristics.get(CameraCharacteristics.SENSOR_ORIENTATION) ?: 90
                setOrientationHint(sensorOrientation)
                prepare()
            }

            val recorderSurface = mediaRecorder!!.surface
            val device = cameraDevice ?: throw IllegalStateException("CameraDevice closed")
            val surfaces = mutableListOf<Surface>(previewSurface!!, recorderSurface)

            val recordBuilder = device.createCaptureRequest(CameraDevice.TEMPLATE_RECORD)
            recordBuilder.addTarget(previewSurface!!)
            recordBuilder.addTarget(recorderSurface)
            applyCachedSettings(recordBuilder)

            device.createCaptureSession(surfaces, object : CameraCaptureSession.StateCallback() {
                override fun onConfigured(session: CameraCaptureSession) {
                    captureSession = session
                    try {
                        session.setRepeatingRequest(recordBuilder.build(), null, backgroundHandler)
                        mediaRecorder?.start()
                        isRecordingVideo = true
                        isRecordingPaused = false
                        postOnMain { result.success(null) }
                    } catch (e: Exception) {
                        postOnMain { result.error("RECORDING_START_ERROR", e.localizedMessage, null) }
                    }
                }

                override fun onConfigureFailed(session: CameraCaptureSession) {
                    postOnMain { result.error("SESSION_FAIL", "Failed to configure video recording", null) }
                }
            }, backgroundHandler)
        } catch (e: Exception) {
            result.error("VIDEO_RECORD_ERROR", e.localizedMessage, null)
        }
    }

    fun pauseVideoRecording(result: MethodChannel.Result) {
        if (!isRecordingVideo || isRecordingPaused) {
            result.success(null)
            return
        }
        try {
            mediaRecorder?.pause()
            isRecordingPaused = true
            result.success(null)
        } catch (e: Exception) {
            result.error("PAUSE_ERROR", e.localizedMessage, null)
        }
    }

    fun resumeVideoRecording(result: MethodChannel.Result) {
        if (!isRecordingVideo || !isRecordingPaused) {
            result.success(null)
            return
        }
        try {
            mediaRecorder?.resume()
            isRecordingPaused = false
            result.success(null)
        } catch (e: Exception) {
            result.error("RESUME_ERROR", e.localizedMessage, null)
        }
    }

    fun stopVideoRecording(result: MethodChannel.Result) {
        if (!isRecordingVideo) {
            result.error("NOT_RECORDING", "Video recording is not active", null)
            return
        }

        try {
            mediaRecorder?.stop()
            mediaRecorder?.reset()
            mediaRecorder?.release()
            mediaRecorder = null
            isRecordingVideo = false
            isRecordingPaused = false

            val path = currentVideoPath ?: ""
            val file = File(path)
            val bytesLength = if (file.exists()) file.length() else 0L

            // Restore preview capture session
            startCaptureSession()

            result.success(
                mapOf(
                    "path" to path,
                    "bytesLength" to bytesLength
                )
            )
        } catch (e: Exception) {
            result.error("STOP_RECORDING_ERROR", e.localizedMessage, null)
        }
    }

    fun setupImageStream(sink: EventChannel.EventSink) {
        imageStreamSink = sink
        if (streamReader == null) {
            val streamWidth = if (previewWidth > 1280) 1280 else previewWidth
            val streamHeight = if (previewHeight > 720) 720 else previewHeight

            streamReader = ImageReader.newInstance(streamWidth, streamHeight, ImageFormat.YUV_420_888, 2)
            streamReader!!.setOnImageAvailableListener({ reader ->
                val image = reader.acquireLatestImage() ?: return@setOnImageAvailableListener
                val currentSink = imageStreamSink ?: run {
                    image.close()
                    return@setOnImageAvailableListener
                }

                val planesList = mutableListOf<Map<String, Any?>>()
                for (plane in image.planes) {
                    val buffer = plane.buffer
                    val bytes = ByteArray(buffer.remaining())
                    buffer.get(bytes)
                    planesList.add(
                        mapOf(
                            "bytes" to bytes,
                            "bytesPerRow" to plane.rowStride,
                            "bytesPerPixel" to plane.pixelStride
                        )
                    )
                }

                val event = mapOf(
                    "format" to "yuv420",
                    "width" to image.width,
                    "height" to image.height,
                    "timestamp" to image.timestamp,
                    "sensorOrientation" to (characteristics.get(CameraCharacteristics.SENSOR_ORIENTATION) ?: 0),
                    "planes" to planesList
                )
                image.close()

                postOnMain {
                    try {
                        currentSink.success(event)
                    } catch (_: Exception) {}
                }
            }, backgroundHandler)

            // Recreate session with streamReader surface
            startCaptureSession()
        }
    }

    fun stopImageStream(result: MethodChannel.Result) {
        imageStreamSink = null
        streamReader?.close()
        streamReader = null
        startCaptureSession()
        result.success(null)
    }

    fun setIso(iso: Int, result: MethodChannel.Result) {
        val builder = previewRequestBuilder ?: run {
            result.error("NOT_INITIALIZED", "Camera preview request not ready", null)
            return
        }

        activeIso = iso
        builder.set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_OFF)
        builder.set(CaptureRequest.SENSOR_SENSITIVITY, iso)
        updateRepeatingRequest()
        result.success(null)
    }

    fun setExposureDuration(durationMicros: Long, result: MethodChannel.Result) {
        val builder = previewRequestBuilder ?: run {
            result.error("NOT_INITIALIZED", "Camera preview request not ready", null)
            return
        }

        val durationNs = durationMicros * 1000L
        activeExposureDurationNs = durationNs
        builder.set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_OFF)
        builder.set(CaptureRequest.SENSOR_EXPOSURE_TIME, durationNs)
        updateRepeatingRequest()
        result.success(null)
    }

    fun setExposureMode(mode: String, result: MethodChannel.Result) {
        val builder = previewRequestBuilder ?: run {
            result.error("NOT_INITIALIZED", "Camera preview request not ready", null)
            return
        }

        when (mode.lowercase()) {
            "auto", "continuous" -> {
                activeIso = null
                activeExposureDurationNs = null
                builder.set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_ON)
            }
            "locked" -> {
                builder.set(CaptureRequest.CONTROL_AE_LOCK, true)
            }
            "manual" -> {
                builder.set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_OFF)
            }
        }
        updateRepeatingRequest()
        result.success(null)
    }

    fun setExposureBias(bias: Double, result: MethodChannel.Result) {
        val builder = previewRequestBuilder ?: run {
            result.error("NOT_INITIALIZED", "Camera preview request not ready", null)
            return
        }

        val stepRational = characteristics.get(CameraCharacteristics.CONTROL_AE_COMPENSATION_STEP)
        val step = stepRational?.toFloat() ?: 0.333f
        val biasSteps = Math.round(bias / step).toInt()
        builder.set(CaptureRequest.CONTROL_AE_EXPOSURE_COMPENSATION, biasSteps)
        updateRepeatingRequest()
        result.success(null)
    }

    fun setFocusMode(mode: String, result: MethodChannel.Result) {
        val builder = previewRequestBuilder ?: run {
            result.error("NOT_INITIALIZED", "Camera preview request not ready", null)
            return
        }

        when (mode.lowercase()) {
            "auto" -> builder.set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_AUTO)
            "continuous" -> builder.set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE)
            "locked" -> {
                builder.set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_AUTO)
                builder.set(CaptureRequest.CONTROL_AF_TRIGGER, CaptureRequest.CONTROL_AF_TRIGGER_START)
            }
            "manual" -> {
                builder.set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_OFF)
            }
        }
        updateRepeatingRequest()
        result.success(null)
    }

    fun setFocusDistance(distance: Float, result: MethodChannel.Result) {
        val builder = previewRequestBuilder ?: run {
            result.error("NOT_INITIALIZED", "Camera preview request not ready", null)
            return
        }

        activeFocusDistance = distance
        builder.set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_OFF)
        builder.set(CaptureRequest.LENS_FOCUS_DISTANCE, distance)
        updateRepeatingRequest()
        result.success(null)
    }

    fun setPointOfInterest(x: Double, y: Double, result: MethodChannel.Result) {
        val builder = previewRequestBuilder ?: run {
            result.error("NOT_INITIALIZED", "Camera preview request not ready", null)
            return
        }
        val session = captureSession ?: run {
            result.error("NOT_INITIALIZED", "Session not ready", null)
            return
        }

        val sensorRect = characteristics.get(CameraCharacteristics.SENSOR_INFO_ACTIVE_ARRAY_SIZE)
        if (sensorRect != null) {
            val centerX = (sensorRect.left + (x * sensorRect.width())).toInt()
            val centerY = (sensorRect.top + (y * sensorRect.height())).toInt()
            val halfArea = (sensorRect.width() * 0.05).toInt()

            val rect = Rect(
                (centerX - halfArea).coerceAtLeast(sensorRect.left),
                (centerY - halfArea).coerceAtLeast(sensorRect.top),
                (centerX + halfArea).coerceAtMost(sensorRect.right),
                (centerY + halfArea).coerceAtMost(sensorRect.bottom)
            )

            val meteringRect = arrayOf(MeteringRectangle(rect, MeteringRectangle.METERING_WEIGHT_MAX))
            builder.set(CaptureRequest.CONTROL_AF_REGIONS, meteringRect)
            builder.set(CaptureRequest.CONTROL_AE_REGIONS, meteringRect)
            builder.set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_AUTO)
            builder.set(CaptureRequest.CONTROL_AF_TRIGGER, CaptureRequest.CONTROL_AF_TRIGGER_START)

            try {
                session.capture(builder.build(), null, backgroundHandler)
                builder.set(CaptureRequest.CONTROL_AF_TRIGGER, CaptureRequest.CONTROL_AF_TRIGGER_IDLE)
                updateRepeatingRequest()
            } catch (_: Exception) {}
        }

        result.success(null)
    }

    fun setFlashMode(mode: String, result: MethodChannel.Result) {
        val builder = previewRequestBuilder ?: run {
            result.error("NOT_INITIALIZED", "Camera preview request not ready", null)
            return
        }

        activeFlashMode = mode
        when (mode.lowercase()) {
            "off" -> {
                builder.set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_ON)
                builder.set(CaptureRequest.FLASH_MODE, CaptureRequest.FLASH_MODE_OFF)
            }
            "auto" -> {
                builder.set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_ON_AUTO_FLASH)
            }
            "always" -> {
                builder.set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_ON_ALWAYS_FLASH)
            }
            "torch" -> {
                builder.set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_ON)
                builder.set(CaptureRequest.FLASH_MODE, CaptureRequest.FLASH_MODE_TORCH)
            }
        }
        updateRepeatingRequest()
        result.success(null)
    }

    fun setTorchMode(enabled: Boolean, result: MethodChannel.Result) {
        val builder = previewRequestBuilder ?: run {
            result.error("NOT_INITIALIZED", "Camera preview request not ready", null)
            return
        }

        activeTorchEnabled = enabled
        if (enabled) {
            builder.set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_ON)
            builder.set(CaptureRequest.FLASH_MODE, CaptureRequest.FLASH_MODE_TORCH)
        } else {
            builder.set(CaptureRequest.FLASH_MODE, CaptureRequest.FLASH_MODE_OFF)
        }
        updateRepeatingRequest()
        result.success(null)
    }

    fun setWhiteBalanceMode(mode: String, result: MethodChannel.Result) {
        val builder = previewRequestBuilder ?: run {
            result.error("NOT_INITIALIZED", "Camera preview request not ready", null)
            return
        }

        val awbMode = when (mode.lowercase()) {
            "incandescent" -> CaptureRequest.CONTROL_AWB_MODE_INCANDESCENT
            "fluorescent" -> CaptureRequest.CONTROL_AWB_MODE_FLUORESCENT
            "daylight" -> CaptureRequest.CONTROL_AWB_MODE_DAYLIGHT
            "cloudy" -> CaptureRequest.CONTROL_AWB_MODE_CLOUDY_DAYLIGHT
            "twilight" -> CaptureRequest.CONTROL_AWB_MODE_TWILIGHT
            "shade" -> CaptureRequest.CONTROL_AWB_MODE_SHADE
            "locked" -> {
                builder.set(CaptureRequest.CONTROL_AWB_LOCK, true)
                CaptureRequest.CONTROL_AWB_MODE_AUTO
            }
            else -> CaptureRequest.CONTROL_AWB_MODE_AUTO
        }

        builder.set(CaptureRequest.CONTROL_AWB_MODE, awbMode)
        updateRepeatingRequest()
        result.success(null)
    }

    fun setZoom(zoom: Float, result: MethodChannel.Result) {
        val builder = previewRequestBuilder ?: run {
            result.error("NOT_INITIALIZED", "Camera preview request not ready", null)
            return
        }

        activeZoom = zoom
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            builder.set(CaptureRequest.CONTROL_ZOOM_RATIO, zoom)
        } else {
            val sensorRect = characteristics.get(CameraCharacteristics.SENSOR_INFO_ACTIVE_ARRAY_SIZE)
            if (sensorRect != null) {
                val cropWidth = (sensorRect.width() / zoom).toInt()
                val cropHeight = (sensorRect.height() / zoom).toInt()
                val cropX = (sensorRect.width() - cropWidth) / 2
                val cropY = (sensorRect.height() - cropHeight) / 2
                builder.set(CaptureRequest.SCALER_CROP_REGION, Rect(cropX, cropY, cropX + cropWidth, cropY + cropHeight))
            }
        }
        updateRepeatingRequest()
        result.success(null)
    }

    fun setFps(fps: Int, result: MethodChannel.Result) {
        val builder = previewRequestBuilder ?: run {
            result.error("NOT_INITIALIZED", "Camera preview request not ready", null)
            return
        }

        val availableRanges = characteristics.get(CameraCharacteristics.CONTROL_AE_AVAILABLE_TARGET_FPS_RANGES) ?: emptyArray()
        val matchingRange = availableRanges.firstOrNull { it.upper == fps } ?: Range(fps, fps)
        builder.set(CaptureRequest.CONTROL_AE_TARGET_FPS_RANGE, matchingRange)
        updateRepeatingRequest()
        result.success(null)
    }

    fun setStabilizationMode(mode: String, result: MethodChannel.Result) {
        val builder = previewRequestBuilder ?: run {
            result.error("NOT_INITIALIZED", "Camera preview request not ready", null)
            return
        }

        when (mode.lowercase()) {
            "off" -> {
                builder.set(CaptureRequest.CONTROL_VIDEO_STABILIZATION_MODE, CameraMetadata.CONTROL_VIDEO_STABILIZATION_MODE_OFF)
                builder.set(CaptureRequest.LENS_OPTICAL_STABILIZATION_MODE, CameraMetadata.LENS_OPTICAL_STABILIZATION_MODE_OFF)
            }
            "standard" -> {
                builder.set(CaptureRequest.CONTROL_VIDEO_STABILIZATION_MODE, CameraMetadata.CONTROL_VIDEO_STABILIZATION_MODE_ON)
            }
            "cinematic" -> {
                builder.set(CaptureRequest.CONTROL_VIDEO_STABILIZATION_MODE, CameraMetadata.CONTROL_VIDEO_STABILIZATION_MODE_ON)
                builder.set(CaptureRequest.LENS_OPTICAL_STABILIZATION_MODE, CameraMetadata.LENS_OPTICAL_STABILIZATION_MODE_ON)
            }
            else -> {
                builder.set(CaptureRequest.CONTROL_VIDEO_STABILIZATION_MODE, CameraMetadata.CONTROL_VIDEO_STABILIZATION_MODE_OFF)
            }
        }
        updateRepeatingRequest()
        result.success(null)
    }

    fun dispose() {
        try {
            captureSession?.close()
        } catch (_: Exception) {}
        captureSession = null

        try {
            cameraDevice?.close()
        } catch (_: Exception) {}
        cameraDevice = null

        photoReader?.close()
        photoReader = null

        streamReader?.close()
        streamReader = null

        previewSurface?.release()
        previewSurface = null

        try {
            mediaRecorder?.reset()
            mediaRecorder?.release()
        } catch (_: Exception) {}
        mediaRecorder = null

        surfaceEntry.release()
        stopBackgroundThread()
    }

    private fun postOnMain(action: () -> Unit) {
        Handler(Looper.getMainLooper()).post(action)
    }
}
