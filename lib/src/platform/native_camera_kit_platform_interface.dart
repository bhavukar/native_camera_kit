import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import '../models/camera_description.dart';
import '../models/camera_enums.dart';
import '../models/camera_image.dart';
import '../models/captured_media.dart';
import 'native_camera_kit_method_channel.dart';

/// The interface that implementations of native_camera_kit must implement.
abstract class NativeCameraKitPlatform extends PlatformInterface {
  /// Constructs a NativeCameraKitPlatform.
  NativeCameraKitPlatform() : super(token: _token);

  static final Object _token = Object();

  static NativeCameraKitPlatform _instance = MethodChannelNativeCameraKit();

  /// The default instance of [NativeCameraKitPlatform] to use.
  static NativeCameraKitPlatform get instance => _instance;

  /// Platform-specific plugins should set this with their own platform-specific
  /// class that extends [NativeCameraKitPlatform] when they register themselves.
  static set instance(NativeCameraKitPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Returns a list of all available camera sensors and their low-level capabilities.
  Future<List<NativeCameraDescription>> availableCameras() {
    throw UnimplementedError('availableCameras() has not been implemented.');
  }

  /// Creates and opens a native camera session on the given sensor.
  ///
  /// Returns a map containing:
  /// - `textureId`: The Flutter texture ID for rendering.
  /// - `previewWidth`: Resolved preview width.
  /// - `previewHeight`: Resolved preview height.
  Future<Map<String, dynamic>> create({
    required String cameraId,
    required ResolutionPreset resolutionPreset,
    required bool enableAudio,
    required ImageFormatGroup imageFormatGroup,
  }) {
    throw UnimplementedError('create() has not been implemented.');
  }

  /// Starts the camera preview session.
  Future<void> initialize(int textureId) {
    throw UnimplementedError('initialize() has not been implemented.');
  }

  /// Disposes native hardware resources associated with this camera session.
  Future<void> dispose(int textureId) {
    throw UnimplementedError('dispose() has not been implemented.');
  }

  /// Captures a high-resolution still image.
  Future<CapturedImage> takePicture(int textureId, {String? path}) {
    throw UnimplementedError('takePicture() has not been implemented.');
  }

  /// Begins recording a hardware-encoded video.
  Future<void> startVideoRecording(int textureId, {String? path}) {
    throw UnimplementedError('startVideoRecording() has not been implemented.');
  }

  /// Pauses the current video recording session.
  Future<void> pauseVideoRecording(int textureId) {
    throw UnimplementedError('pauseVideoRecording() has not been implemented.');
  }

  /// Resumes a paused video recording session.
  Future<void> resumeVideoRecording(int textureId) {
    throw UnimplementedError('resumeVideoRecording() has not been implemented.');
  }

  /// Stops video recording and returns the saved file metadata.
  Future<CapturedVideo> stopVideoRecording(int textureId) {
    throw UnimplementedError('stopVideoRecording() has not been implemented.');
  }

  /// Sets the flash operating mode for still capture.
  Future<void> setFlashMode(int textureId, FlashMode mode) {
    throw UnimplementedError('setFlashMode() has not been implemented.');
  }

  /// Sets continuous torch light mode and brightness level (0.0 to 1.0).
  Future<void> setTorchMode(int textureId, bool enabled, {double level = 1.0}) {
    throw UnimplementedError('setTorchMode() has not been implemented.');
  }

  /// Configures autofocus mode.
  Future<void> setFocusMode(int textureId, FocusMode mode) {
    throw UnimplementedError('setFocusMode() has not been implemented.');
  }

  /// Sets manual focus distance (0.0 = infinity, up to maxFocusDistance = closest macro).
  Future<void> setFocusDistance(int textureId, double distance) {
    throw UnimplementedError('setFocusDistance() has not been implemented.');
  }

  /// Configures point of interest for autofocus and autoexposure.
  ///
  /// Normalized coordinates [x] and [y] range from 0.0 to 1.0.
  Future<void> setPointOfInterest(int textureId, double x, double y) {
    throw UnimplementedError('setPointOfInterest() has not been implemented.');
  }

  /// Configures auto-exposure or manual exposure mode.
  Future<void> setExposureMode(int textureId, ExposureMode mode) {
    throw UnimplementedError('setExposureMode() has not been implemented.');
  }

  /// Sets manual ISO sensitivity.
  Future<void> setIso(int textureId, int iso) {
    throw UnimplementedError('setIso() has not been implemented.');
  }

  /// Sets manual exposure duration (shutter speed) in microseconds.
  Future<void> setExposureDuration(int textureId, int durationMicros) {
    throw UnimplementedError('setExposureDuration() has not been implemented.');
  }

  /// Adjusts exposure compensation target bias in EV steps.
  Future<void> setExposureBias(int textureId, double bias) {
    throw UnimplementedError('setExposureBias() has not been implemented.');
  }

  /// Configures white balance preset or custom color temperature in Kelvin.
  Future<void> setWhiteBalanceMode(
    int textureId,
    WhiteBalanceMode mode, {
    int? temperatureKelvin,
  }) {
    throw UnimplementedError('setWhiteBalanceMode() has not been implemented.');
  }

  /// Sets the optical / digital zoom factor (e.g. 1.0, 2.0, 5.0).
  Future<void> setZoom(int textureId, double zoom) {
    throw UnimplementedError('setZoom() has not been implemented.');
  }

  /// Sets the target frame rate in frames per second.
  Future<void> setFps(int textureId, int fps) {
    throw UnimplementedError('setFps() has not been implemented.');
  }

  /// Configures hardware video stabilization.
  Future<void> setStabilizationMode(int textureId, StabilizationMode mode) {
    throw UnimplementedError('setStabilizationMode() has not been implemented.');
  }

  /// Starts streaming raw video frame buffers directly from the camera pipeline.
  Stream<CameraImage> startImageStream(int textureId) {
    throw UnimplementedError('startImageStream() has not been implemented.');
  }

  /// Stops streaming raw video frames.
  Future<void> stopImageStream(int textureId) {
    throw UnimplementedError('stopImageStream() has not been implemented.');
  }
}
