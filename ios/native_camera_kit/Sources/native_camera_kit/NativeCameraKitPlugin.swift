import AVFoundation
import Flutter
import UIKit

public class NativeCameraKitPlugin: NSObject, FlutterPlugin {
    private let textureRegistry: FlutterTextureRegistry
    private let binaryMessenger: FlutterBinaryMessenger
    private var sessions: [Int64: NativeCameraSession] = [:]

    init(textureRegistry: FlutterTextureRegistry, binaryMessenger: FlutterBinaryMessenger) {
        self.textureRegistry = textureRegistry
        self.binaryMessenger = binaryMessenger
        super.init()
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "dev.bhavuk.native_camera_kit", binaryMessenger: registrar.messenger())
        let instance = NativeCameraKitPlugin(
            textureRegistry: registrar.textures(),
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]

        switch call.method {
        case "availableCameras":
            handleAvailableCameras(result: result)

        case "create":
            handleCreate(args: args, result: result)

        case "initialize":
            guard let textureId = (args["textureId"] as? NSNumber)?.int64Value,
                  let session = sessions[textureId] else {
                result(FlutterError(code: "INVALID_TEXTURE_ID", message: "Session not found", details: nil))
                return
            }
            session.start()
            result(nil)

        case "dispose":
            guard let textureId = (args["textureId"] as? NSNumber)?.int64Value else {
                result(nil)
                return
            }
            if let session = sessions.removeValue(forKey: textureId) {
                session.dispose()
            }
            result(nil)

        case "takePicture":
            guard let textureId = (args["textureId"] as? NSNumber)?.int64Value,
                  let session = sessions[textureId] else {
                result(FlutterError(code: "INVALID_ID", message: "Session not found", details: nil))
                return
            }
            let path = args["path"] as? String
            session.takePicture(path: path) { captureResult in
                DispatchQueue.main.async {
                    switch captureResult {
                    case .success(let data): result(data)
                    case .failure(let error):
                        result(FlutterError(code: "CAPTURE_ERROR", message: error.localizedDescription, details: nil))
                    }
                }
            }

        case "startVideoRecording":
            guard let textureId = (args["textureId"] as? NSNumber)?.int64Value,
                  let session = sessions[textureId] else {
                result(FlutterError(code: "INVALID_ID", message: "Session not found", details: nil))
                return
            }
            let path = args["path"] as? String
            session.startVideoRecording(path: path) { recordResult in
                switch recordResult {
                case .success: result(nil)
                case .failure(let error):
                    result(FlutterError(code: "START_RECORDING_ERROR", message: error.localizedDescription, details: nil))
                }
            }

        case "pauseVideoRecording", "resumeVideoRecording":
            // iOS AVCaptureMovieFileOutput doesn't support pause/resume natively without asset writer; return success
            result(nil)

        case "stopVideoRecording":
            guard let textureId = (args["textureId"] as? NSNumber)?.int64Value,
                  let session = sessions[textureId] else {
                result(FlutterError(code: "INVALID_ID", message: "Session not found", details: nil))
                return
            }
            session.stopVideoRecording { stopResult in
                DispatchQueue.main.async {
                    switch stopResult {
                    case .success(let data): result(data)
                    case .failure(let error):
                        result(FlutterError(code: "STOP_RECORDING_ERROR", message: error.localizedDescription, details: nil))
                    }
                }
            }

        case "setFlashMode":
            guard let textureId = (args["textureId"] as? NSNumber)?.int64Value,
                  let session = sessions[textureId] else {
                result(FlutterError(code: "INVALID_ID", message: "Session not found", details: nil))
                return
            }
            let mode = args["mode"] as? String ?? "auto"
            session.setFlashMode(mode)
            result(nil)

        case "setTorchMode":
            guard let textureId = (args["textureId"] as? NSNumber)?.int64Value,
                  let session = sessions[textureId] else {
                result(FlutterError(code: "INVALID_ID", message: "Session not found", details: nil))
                return
            }
            let enabled = args["enabled"] as? Bool ?? false
            let level = (args["level"] as? NSNumber)?.floatValue ?? 1.0
            do {
                try session.setTorchMode(enabled: enabled, level: level)
                result(nil)
            } catch {
                result(FlutterError(code: "TORCH_ERROR", message: error.localizedDescription, details: nil))
            }

        case "setFocusMode":
            guard let textureId = (args["textureId"] as? NSNumber)?.int64Value,
                  let session = sessions[textureId] else {
                result(FlutterError(code: "INVALID_ID", message: "Session not found", details: nil))
                return
            }
            let mode = args["mode"] as? String ?? "auto"
            do {
                try session.setFocusMode(mode)
                result(nil)
            } catch {
                result(FlutterError(code: "FOCUS_ERROR", message: error.localizedDescription, details: nil))
            }

        case "setFocusDistance":
            guard let textureId = (args["textureId"] as? NSNumber)?.int64Value,
                  let session = sessions[textureId] else {
                result(FlutterError(code: "INVALID_ID", message: "Session not found", details: nil))
                return
            }
            let distance = (args["distance"] as? NSNumber)?.floatValue ?? 0.0
            do {
                try session.setFocusDistance(distance)
                result(nil)
            } catch {
                result(FlutterError(code: "FOCUS_DISTANCE_ERROR", message: error.localizedDescription, details: nil))
            }

        case "setPointOfInterest":
            guard let textureId = (args["textureId"] as? NSNumber)?.int64Value,
                  let session = sessions[textureId] else {
                result(FlutterError(code: "INVALID_ID", message: "Session not found", details: nil))
                return
            }
            let x = (args["x"] as? NSNumber)?.doubleValue ?? 0.5
            let y = (args["y"] as? NSNumber)?.doubleValue ?? 0.5
            do {
                try session.setPointOfInterest(x: x, y: y)
                result(nil)
            } catch {
                result(FlutterError(code: "POI_ERROR", message: error.localizedDescription, details: nil))
            }

        case "setExposureMode":
            guard let textureId = (args["textureId"] as? NSNumber)?.int64Value,
                  let session = sessions[textureId] else {
                result(FlutterError(code: "INVALID_ID", message: "Session not found", details: nil))
                return
            }
            let mode = args["mode"] as? String ?? "auto"
            do {
                try session.setExposureMode(mode)
                result(nil)
            } catch {
                result(FlutterError(code: "EXPOSURE_ERROR", message: error.localizedDescription, details: nil))
            }

        case "setIso":
            guard let textureId = (args["textureId"] as? NSNumber)?.int64Value,
                  let session = sessions[textureId] else {
                result(FlutterError(code: "INVALID_ID", message: "Session not found", details: nil))
                return
            }
            let iso = (args["iso"] as? NSNumber)?.floatValue ?? 100.0
            do {
                try session.setIso(iso)
                result(nil)
            } catch {
                result(FlutterError(code: "ISO_ERROR", message: error.localizedDescription, details: nil))
            }

        case "setExposureDuration":
            guard let textureId = (args["textureId"] as? NSNumber)?.int64Value,
                  let session = sessions[textureId] else {
                result(FlutterError(code: "INVALID_ID", message: "Session not found", details: nil))
                return
            }
            let durationMicros = (args["durationMicros"] as? NSNumber)?.int64Value ?? 10000
            do {
                try session.setExposureDurationMicros(durationMicros)
                result(nil)
            } catch {
                result(FlutterError(code: "DURATION_ERROR", message: error.localizedDescription, details: nil))
            }

        case "setExposureBias":
            guard let textureId = (args["textureId"] as? NSNumber)?.int64Value,
                  let session = sessions[textureId] else {
                result(FlutterError(code: "INVALID_ID", message: "Session not found", details: nil))
                return
            }
            let bias = (args["bias"] as? NSNumber)?.floatValue ?? 0.0
            do {
                try session.setExposureBias(bias)
                result(nil)
            } catch {
                result(FlutterError(code: "BIAS_ERROR", message: error.localizedDescription, details: nil))
            }

        case "setWhiteBalanceMode":
            guard let textureId = (args["textureId"] as? NSNumber)?.int64Value,
                  let session = sessions[textureId] else {
                result(FlutterError(code: "INVALID_ID", message: "Session not found", details: nil))
                return
            }
            let mode = args["mode"] as? String ?? "auto"
            let kelvin = (args["temperatureKelvin"] as? NSNumber)?.intValue
            do {
                try session.setWhiteBalanceMode(mode, kelvin: kelvin)
                result(nil)
            } catch {
                result(FlutterError(code: "WB_ERROR", message: error.localizedDescription, details: nil))
            }

        case "setZoom":
            guard let textureId = (args["textureId"] as? NSNumber)?.int64Value,
                  let session = sessions[textureId] else {
                result(FlutterError(code: "INVALID_ID", message: "Session not found", details: nil))
                return
            }
            let zoom = (args["zoom"] as? NSNumber)?.floatValue ?? 1.0
            do {
                try session.setZoom(zoom)
                result(nil)
            } catch {
                result(FlutterError(code: "ZOOM_ERROR", message: error.localizedDescription, details: nil))
            }

        case "setFps":
            guard let textureId = (args["textureId"] as? NSNumber)?.int64Value,
                  let session = sessions[textureId] else {
                result(FlutterError(code: "INVALID_ID", message: "Session not found", details: nil))
                return
            }
            let fps = (args["fps"] as? NSNumber)?.intValue ?? 30
            do {
                try session.setFps(fps)
                result(nil)
            } catch {
                result(FlutterError(code: "FPS_ERROR", message: error.localizedDescription, details: nil))
            }

        case "setStabilizationMode":
            guard let textureId = (args["textureId"] as? NSNumber)?.int64Value,
                  let session = sessions[textureId] else {
                result(FlutterError(code: "INVALID_ID", message: "Session not found", details: nil))
                return
            }
            let mode = args["mode"] as? String ?? "auto"
            session.setStabilizationMode(mode)
            result(nil)

        case "stopImageStream":
            guard let textureId = (args["textureId"] as? NSNumber)?.int64Value,
                  let session = sessions[textureId] else {
                result(nil)
                return
            }
            session.imageStreamSink = nil
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func handleAvailableCameras(result: @escaping FlutterResult) {
        var deviceTypes: [AVCaptureDevice.DeviceType] = [
            .builtInWideAngleCamera,
            .builtInTelephotoCamera
        ]
        if #available(iOS 13.0, *) {
            deviceTypes.append(.builtInUltraWideCamera)
            deviceTypes.append(.builtInTripleCamera)
            deviceTypes.append(.builtInDualWideCamera)
        }

        let session = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: .unspecified
        )

        var cameras: [[String: Any]] = []
        for dev in session.devices {
            let position: String = switch dev.position {
            case .front: "front"
            case .back: "back"
            default: "external"
            }

            var fpsRanges: [[String: Any]] = []
            for range in dev.activeFormat.videoSupportedFrameRateRanges {
                fpsRanges.append([
                    "min": Int(range.minFrameRate),
                    "max": Int(range.maxFrameRate)
                ])
            }

            let minDurationMicros = Int(CMTimeGetSeconds(dev.activeFormat.minExposureDuration) * 1_000_000)
            let maxDurationMicros = Int(CMTimeGetSeconds(dev.activeFormat.maxExposureDuration) * 1_000_000)

            cameras.append([
                "id": dev.uniqueID,
                "name": dev.localizedName,
                "position": position,
                "sensorOrientation": 90,
                "minIso": Int(dev.activeFormat.minISO),
                "maxIso": Int(dev.activeFormat.maxISO),
                "minExposureDurationMicros": minDurationMicros,
                "maxExposureDurationMicros": maxDurationMicros,
                "minFocusDistance": 0.0,
                "maxFocusDistance": 1.0,
                "minZoom": Double(dev.minAvailableVideoZoomFactor),
                "maxZoom": Double(min(dev.maxAvailableVideoZoomFactor, 10.0)),
                "minExposureBias": Double(dev.minExposureTargetBias),
                "maxExposureBias": Double(dev.maxExposureTargetBias),
                "exposureBiasStep": 0.333,
                "supportedFpsRanges": fpsRanges,
                "supportsFlash": dev.isFlashAvailable,
                "supportsTorch": dev.isTorchAvailable,
                "supportsManualFocus": dev.isFocusModeSupported(.locked),
                "supportsManualExposure": dev.isExposureModeSupported(.custom)
            ])
        }

        result(cameras)
    }

    private func handleCreate(args: [String: Any], result: @escaping FlutterResult) {
        let cameraId = args["cameraId"] as? String ?? ""
        let resolutionPreset = args["resolutionPreset"] as? String ?? "veryHigh"
        let enableAudio = args["enableAudio"] as? Bool ?? true
        let imageFormatGroup = args["imageFormatGroup"] as? String ?? "bgra8888"

        guard let device = AVCaptureDevice(uniqueID: cameraId) ?? AVCaptureDevice.default(for: .video) else {
            result(FlutterError(code: "CAMERA_NOT_FOUND", message: "Could not find camera with ID \(cameraId)", details: nil))
            return
        }

        do {
            let session = try NativeCameraSession(
                device: device,
                resolutionPreset: resolutionPreset,
                enableAudio: enableAudio,
                imageFormatGroup: imageFormatGroup,
                textureRegistry: textureRegistry,
                binaryMessenger: binaryMessenger
            )

            let realTextureId = textureRegistry.register(session)
            session.textureId = realTextureId

            // Setup streaming EventChannel
            let eventChannel = FlutterEventChannel(
                name: "dev.bhavuk.native_camera_kit/image_stream_\(realTextureId)",
                binaryMessenger: binaryMessenger
            )
            eventChannel.setStreamHandler(StreamHandler(session: session))

            sessions[realTextureId] = session

            result([
                "textureId": realTextureId,
                "previewWidth": session.previewWidth,
                "previewHeight": session.previewHeight
            ])
        } catch {
            result(FlutterError(code: "CREATE_FAILED", message: error.localizedDescription, details: nil))
        }
    }
}

private class StreamHandler: NSObject, FlutterStreamHandler {
    private weak var session: NativeCameraSession?

    init(session: NativeCameraSession) {
        self.session = session
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        session?.imageStreamSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        session?.imageStreamSink = nil
        return nil
    }
}
