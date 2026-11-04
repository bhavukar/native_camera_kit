import AVFoundation
import Flutter
import Foundation

class NativeCameraSession: NSObject, FlutterTexture, AVCaptureVideoDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate, AVCaptureFileOutputRecordingDelegate {
    var textureId: Int64 = -1
    let device: AVCaptureDevice
    let captureSession: AVCaptureSession
    let textureRegistry: FlutterTextureRegistry
    let binaryMessenger: FlutterBinaryMessenger

    private var videoInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?
    private var videoDataOutput: AVCaptureVideoDataOutput?
    private var photoOutput: AVCapturePhotoOutput?
    private var movieFileOutput: AVCaptureMovieFileOutput?

    private var latestPixelBuffer: CVPixelBuffer?
    private let pixelBufferLock = NSLock()

    private var photoCompletion: ((Result<[String: Any], Error>) -> Void)?
    private var videoRecordCompletion: ((Result<[String: Any], Error>) -> Void)?
    private var activeVideoUrl: URL?

    var imageStreamSink: FlutterEventSink?

    var previewWidth: Int = 1920
    var previewHeight: Int = 1080

    // Manual controls cache
    private var activeIso: Float?
    private var activeDuration: CMTime?
    private var activeFocusDistance: Float?

    init(
        device: AVCaptureDevice,
        resolutionPreset: String,
        enableAudio: Bool,
        imageFormatGroup: String,
        textureRegistry: FlutterTextureRegistry,
        binaryMessenger: FlutterBinaryMessenger
    ) throws {
        self.device = device
        self.textureRegistry = textureRegistry
        self.binaryMessenger = binaryMessenger
        self.captureSession = AVCaptureSession()

        super.init()

        // Configure session preset
        let preset: AVCaptureSession.Preset = switch resolutionPreset.lowercased() {
        case "low": .cif352x288
        case "medium": .vga640x480
        case "high": .hd1280x720
        case "veryhigh": .hd1920x1080
        case "ultrahigh": .hd4K3840x2160
        default: .hd1920x1080
        }

        if captureSession.canSetSessionPreset(preset) {
            captureSession.sessionPreset = preset
        } else {
            captureSession.sessionPreset = .high
        }

        // Add Video Input
        let vInput = try AVCaptureDeviceInput(device: device)
        if captureSession.canAddInput(vInput) {
            captureSession.addInput(vInput)
            self.videoInput = vInput
        }

        // Add Audio Input if requested
        if enableAudio, let audioDevice = AVCaptureDevice.default(for: .audio) {
            if let aInput = try? AVCaptureDeviceInput(device: audioDevice), captureSession.canAddInput(aInput) {
                captureSession.addInput(aInput)
                self.audioInput = aInput
            }
        }

        // Video Data Output for Texture preview and raw frame streaming
        let vOutput = AVCaptureVideoDataOutput()
        vOutput.alwaysDiscardsLateVideoFrames = true
        vOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]

        let queue = DispatchQueue(label: "dev.bhavuk.native_camera_kit.videoQueue-\(UUID().uuidString)")
        vOutput.setSampleBufferDelegate(self, queue: queue)

        if captureSession.canAddOutput(vOutput) {
            captureSession.addOutput(vOutput)
            self.videoDataOutput = vOutput
        }

        // Photo Output
        let pOutput = AVCapturePhotoOutput()
        if captureSession.canAddOutput(pOutput) {
            captureSession.addOutput(pOutput)
            self.photoOutput = pOutput
        }

        // Movie File Output for video recording
        let mOutput = AVCaptureMovieFileOutput()
        if captureSession.canAddOutput(mOutput) {
            captureSession.addOutput(mOutput)
            self.movieFileOutput = mOutput
        }

        // Compute resolved dimensions
        let dimensions = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
        self.previewWidth = Int(dimensions.width)
        self.previewHeight = Int(dimensions.height)
    }

    func start() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
        }
    }

    // MARK: - FlutterTexture
    func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        pixelBufferLock.lock()
        defer { pixelBufferLock.unlock() }

        guard let buffer = latestPixelBuffer else { return nil }
        return Unmanaged.passRetained(buffer)
    }

    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        pixelBufferLock.lock()
        latestPixelBuffer = pixelBuffer
        pixelBufferLock.unlock()

        textureRegistry.textureFrameAvailable(textureId)

        // Raw frame stream delivery
        if let sink = imageStreamSink {
            CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
            let width = CVPixelBufferGetWidth(pixelBuffer)
            let height = CVPixelBufferGetHeight(pixelBuffer)
            let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)

            if let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) {
                let totalBytes = bytesPerRow * height
                let data = Data(bytes: baseAddress, count: totalBytes)

                let event: [String: Any] = [
                    "format": "bgra8888",
                    "width": width,
                    "height": height,
                    "timestamp": Int(CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds * 1000),
                    "sensorOrientation": 90,
                    "planes": [
                        [
                            "bytes": FlutterStandardTypedData(bytes: data),
                            "bytesPerRow": bytesPerRow,
                            "bytesPerPixel": 4
                        ]
                    ]
                ]

                DispatchQueue.main.async {
                    sink(event)
                }
            }
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        }
    }

    // MARK: - Still Photo Capture
    func takePicture(path: String?, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        guard let photoOutput = photoOutput else {
            completion(.failure(NSError(domain: "NativeCameraKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "Photo output not ready"])))
            return
        }

        self.photoCompletion = completion

        let settings = AVCapturePhotoSettings()
        if device.isFlashAvailable {
            settings.flashMode = .auto
        }

        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let completion = photoCompletion else { return }
        self.photoCompletion = nil

        if let error = error {
            completion(.failure(error))
            return
        }

        guard let fileData = photo.fileDataRepresentation() else {
            completion(.failure(NSError(domain: "NativeCameraKit", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to get photo data"])))
            return
        }

        let tempUrl = FileManager.default.temporaryDirectory.appendingPathComponent("photo_\(Date().timeIntervalSince1970).jpg")
        do {
            try fileData.write(to: tempUrl)
            let dimensions = photo.resolvedSettings.photoDimensions
            completion(.success([
                "path": tempUrl.path,
                "width": Int(dimensions.width),
                "height": Int(dimensions.height),
                "bytesLength": fileData.count,
                "mimeType": "image/jpeg"
            ]))
        } catch {
            completion(.failure(error))
        }
    }

    // MARK: - Video Recording
    func startVideoRecording(path: String?, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let movieOutput = movieFileOutput else {
            completion(.failure(NSError(domain: "NativeCameraKit", code: -3, userInfo: [NSLocalizedDescriptionKey: "Movie output not ready"])))
            return
        }

        let destinationUrl = path != nil
            ? URL(fileURLWithPath: path!)
            : FileManager.default.temporaryDirectory.appendingPathComponent("video_\(Date().timeIntervalSince1970).mp4")

        self.activeVideoUrl = destinationUrl
        movieOutput.startRecording(to: destinationUrl, recordingDelegate: self)
        completion(.success(()))
    }

    func stopVideoRecording(completion: @escaping (Result<[String: Any], Error>) -> Void) {
        guard let movieOutput = movieFileOutput, movieOutput.isRecording else {
            completion(.failure(NSError(domain: "NativeCameraKit", code: -4, userInfo: [NSLocalizedDescriptionKey: "No video recording in progress"])))
            return
        }

        self.videoRecordCompletion = completion
        movieOutput.stopRecording()
    }

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        guard let completion = videoRecordCompletion else { return }
        self.videoRecordCompletion = nil

        if let error = error {
            completion(.failure(error))
            return
        }

        let fileData = try? Data(contentsOf: outputFileURL)
        let byteCount = fileData?.count ?? 0

        completion(.success([
            "path": outputFileURL.path,
            "bytesLength": byteCount
        ]))
    }

    // MARK: - Manual Controls
    func setIso(_ iso: Float) throws {
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }

        activeIso = iso
        let duration = activeDuration ?? device.exposureDuration
        let clampedIso = min(max(iso, device.activeFormat.minISO), device.activeFormat.maxISO)
        device.setExposureModeCustom(duration: duration, iso: clampedIso, completionHandler: nil)
    }

    func setExposureDurationMicros(_ durationMicros: Int64) throws {
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }

        let duration = CMTime(value: durationMicros, timescale: 1_000_000)
        activeDuration = duration
        let iso = activeIso ?? device.iso
        let clampedDuration = min(max(duration, device.activeFormat.minExposureDuration), device.activeFormat.maxExposureDuration)
        device.setExposureModeCustom(duration: clampedDuration, iso: iso, completionHandler: nil)
    }

    func setExposureMode(_ mode: String) throws {
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }

        switch mode.lowercased() {
        case "auto", "continuous":
            activeIso = nil
            activeDuration = nil
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
        case "locked":
            if device.isExposureModeSupported(.locked) {
                device.exposureMode = .locked
            }
        case "manual":
            let iso = activeIso ?? device.iso
            let duration = activeDuration ?? device.exposureDuration
            device.setExposureModeCustom(duration: duration, iso: iso, completionHandler: nil)
        default:
            break
        }
    }

    func setExposureBias(_ bias: Float) throws {
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }

        let clampedBias = min(max(bias, device.minExposureTargetBias), device.maxExposureTargetBias)
        device.setExposureTargetBias(clampedBias, completionHandler: nil)
    }

    func setFocusMode(_ mode: String) throws {
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }

        switch mode.lowercased() {
        case "auto":
            if device.isFocusModeSupported(.autoFocus) {
                device.focusMode = .autoFocus
            }
        case "continuous":
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
        case "locked":
            if device.isFocusModeSupported(.locked) {
                device.focusMode = .locked
            }
        case "manual":
            let pos = activeFocusDistance ?? 0.5
            device.setFocusModeLocked(lensPosition: pos, completionHandler: nil)
        default:
            break
        }
    }

    func setFocusDistance(_ distance: Float) throws {
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }

        activeFocusDistance = distance
        let clampedPos = min(max(distance, 0.0), 1.0)
        device.setFocusModeLocked(lensPosition: clampedPos, completionHandler: nil)
    }

    func setPointOfInterest(x: Double, y: Double) throws {
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }

        let point = CGPoint(x: x, y: y)
        if device.isFocusPointOfInterestSupported {
            device.focusPointOfInterest = point
            device.focusMode = .autoFocus
        }
        if device.isExposurePointOfInterestSupported {
            device.exposurePointOfInterest = point
            device.exposureMode = .autoExpose
        }
    }

    func setFlashMode(_ mode: String) {
        // Flash mode is handled dynamically during photo capture settings
    }

    func setTorchMode(enabled: Bool, level: Float = 1.0) throws {
        guard device.isTorchAvailable else { return }
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }

        if enabled {
            let clampedLevel = min(max(level, 0.01), 1.0)
            try device.setTorchModeOn(level: clampedLevel)
        } else {
            device.torchMode = .off
        }
    }

    func setWhiteBalanceMode(_ mode: String, kelvin: Int?) throws {
        guard device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) else { return }
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }

        switch mode.lowercased() {
        case "auto":
            device.whiteBalanceMode = .continuousAutoWhiteBalance
        case "locked":
            device.whiteBalanceMode = .locked
        case "daylight":
            let gains = device.deviceWhiteBalanceGains(for: AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(temperature: 5500, tint: 0))
            device.setWhiteBalanceModeLocked(with: gains, completionHandler: nil)
        case "cloudy":
            let gains = device.deviceWhiteBalanceGains(for: AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(temperature: 6500, tint: 0))
            device.setWhiteBalanceModeLocked(with: gains, completionHandler: nil)
        case "incandescent":
            let gains = device.deviceWhiteBalanceGains(for: AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(temperature: 3000, tint: 0))
            device.setWhiteBalanceModeLocked(with: gains, completionHandler: nil)
        case "fluorescent":
            let gains = device.deviceWhiteBalanceGains(for: AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(temperature: 4200, tint: 0))
            device.setWhiteBalanceModeLocked(with: gains, completionHandler: nil)
        default:
            if let kelvin = kelvin {
                let gains = device.deviceWhiteBalanceGains(for: AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(temperature: Float(kelvin), tint: 0))
                device.setWhiteBalanceModeLocked(with: gains, completionHandler: nil)
            } else {
                device.whiteBalanceMode = .continuousAutoWhiteBalance
            }
        }
    }

    func setZoom(_ zoom: Float) throws {
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }

        let clampedZoom = min(max(CGFloat(zoom), device.minAvailableVideoZoomFactor), min(device.maxAvailableVideoZoomFactor, 10.0))
        device.videoZoomFactor = clampedZoom
    }

    func setFps(_ fps: Int) throws {
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }

        let frameDuration = CMTime(value: 1, timescale: Int32(fps))
        device.activeVideoMinFrameDuration = frameDuration
        device.activeVideoMaxFrameDuration = frameDuration
    }

    func setStabilizationMode(_ mode: String) {
        guard let connection = videoDataOutput?.connection(with: .video), connection.isVideoStabilizationSupported else { return }

        switch mode.lowercased() {
        case "off":
            connection.preferredVideoStabilizationMode = .off
        case "standard":
            connection.preferredVideoStabilizationMode = .standard
        case "cinematic":
            connection.preferredVideoStabilizationMode = .cinematic
        default:
            connection.preferredVideoStabilizationMode = .auto
        }
    }

    func dispose() {
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
        textureRegistry.unregisterTexture(textureId)
    }
}
