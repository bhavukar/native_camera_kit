import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import '../models/camera_description.dart';
import '../models/camera_enums.dart';
import '../models/camera_image.dart';
import '../models/camera_value.dart';
import '../models/captured_media.dart';
import '../platform/native_camera_kit_platform_interface.dart';

/// Controller providing low-level hardware control over a device camera sensor.
class NativeCameraController extends ValueNotifier<NativeCameraValue> {
  /// The target camera sensor description.
  final NativeCameraDescription description;

  /// Target resolution preset for preview and video streaming.
  final ResolutionPreset resolutionPreset;

  /// Whether to enable audio recording during video capture.
  final bool enableAudio;

  /// Pixel format group for raw frame streaming.
  final ImageFormatGroup imageFormatGroup;

  int? _textureId;
  StreamSubscription<CameraImage>? _imageStreamSubscription;
  bool _isDisposed = false;

  /// Creates a [NativeCameraController].
  NativeCameraController(
    this.description, {
    this.resolutionPreset = ResolutionPreset.veryHigh,
    this.enableAudio = true,
    this.imageFormatGroup = ImageFormatGroup.yuv420,
  }) : super(NativeCameraValue.uninitialized);

  /// Native Flutter texture ID used by [Texture] widget.
  int? get textureId => _textureId;

  /// Whether this controller has been disposed.
  bool get isDisposed => _isDisposed;

  NativeCameraKitPlatform get _platform => NativeCameraKitPlatform.instance;

  /// Initializes the camera hardware and begins the preview stream.
  Future<void> initialize() async {
    if (_isDisposed) {
      throw StateError('Cannot initialize a disposed NativeCameraController');
    }

    try {
      final createResult = await _platform.create(
        cameraId: description.id,
        resolutionPreset: resolutionPreset,
        enableAudio: enableAudio,
        imageFormatGroup: imageFormatGroup,
      );

      final textureId = (createResult['textureId'] as num?)?.toInt();
      if (textureId == null) {
        throw StateError('Failed to create native camera: missing textureId');
      }

      _textureId = textureId;

      final previewWidth = (createResult['previewWidth'] as num?)?.toDouble() ?? 1920.0;
      final previewHeight = (createResult['previewHeight'] as num?)?.toDouble() ?? 1080.0;

      await _platform.initialize(textureId);

      value = value.copyWith(
        isInitialized: true,
        previewSize: Size(previewWidth, previewHeight),
      );
    } catch (e) {
      value = value.copyWith(errorDescription: e.toString());
      rethrow;
    }
  }

  /// Captures a high-resolution still image.
  Future<CapturedImage> takePicture({String? destinationPath}) async {
    _ensureInitialized();
    if (value.isTakingPicture) {
      throw StateError('A picture capture is already in progress');
    }

    value = value.copyWith(isTakingPicture: true);
    try {
      final result = await _platform.takePicture(
        _textureId!,
        path: destinationPath,
      );
      return result;
    } catch (e) {
      value = value.copyWith(errorDescription: e.toString());
      rethrow;
    } finally {
      value = value.copyWith(isTakingPicture: false);
    }
  }

  /// Begins recording video to disk.
  Future<void> startVideoRecording({String? destinationPath}) async {
    _ensureInitialized();
    if (value.isRecordingVideo) {
      throw StateError('Video recording is already active');
    }

    try {
      await _platform.startVideoRecording(_textureId!, path: destinationPath);
      value = value.copyWith(
        isRecordingVideo: true,
        isRecordingPaused: false,
      );
    } catch (e) {
      value = value.copyWith(errorDescription: e.toString());
      rethrow;
    }
  }

  /// Pauses an active video recording session.
  Future<void> pauseVideoRecording() async {
    _ensureInitialized();
    if (!value.isRecordingVideo || value.isRecordingPaused) {
      return;
    }

    try {
      await _platform.pauseVideoRecording(_textureId!);
      value = value.copyWith(isRecordingPaused: true);
    } catch (e) {
      value = value.copyWith(errorDescription: e.toString());
      rethrow;
    }
  }

  /// Resumes a paused video recording session.
  Future<void> resumeVideoRecording() async {
    _ensureInitialized();
    if (!value.isRecordingVideo || !value.isRecordingPaused) {
      return;
    }

    try {
      await _platform.resumeVideoRecording(_textureId!);
      value = value.copyWith(isRecordingPaused: false);
    } catch (e) {
      value = value.copyWith(errorDescription: e.toString());
      rethrow;
    }
  }

  /// Stops video recording and returns the captured video details.
  Future<CapturedVideo> stopVideoRecording() async {
    _ensureInitialized();
    if (!value.isRecordingVideo) {
      throw StateError('No video recording is currently active');
    }

    try {
      final result = await _platform.stopVideoRecording(_textureId!);
      value = value.copyWith(
        isRecordingVideo: false,
        isRecordingPaused: false,
      );
      return result;
    } catch (e) {
      value = value.copyWith(errorDescription: e.toString());
      rethrow;
    }
  }

  /// Starts streaming low-level raw frame buffers directly to [onImage].
  Future<void> startImageStream(void Function(CameraImage image) onImage) async {
    _ensureInitialized();
    if (value.isStreamingImages) {
      throw StateError('An image stream is already active');
    }

    try {
      final stream = _platform.startImageStream(_textureId!);
      _imageStreamSubscription = stream.listen(
        onImage,
        onError: (Object error) {
          value = value.copyWith(errorDescription: error.toString());
        },
      );
      value = value.copyWith(isStreamingImages: true);
    } catch (e) {
      value = value.copyWith(errorDescription: e.toString());
      rethrow;
    }
  }

  /// Stops streaming raw video frames.
  Future<void> stopImageStream() async {
    _ensureInitialized();
    if (!value.isStreamingImages) return;

    try {
      await _imageStreamSubscription?.cancel();
      _imageStreamSubscription = null;
      await _platform.stopImageStream(_textureId!);
      value = value.copyWith(isStreamingImages: false);
    } catch (e) {
      value = value.copyWith(errorDescription: e.toString());
      rethrow;
    }
  }

  /// Sets the flash operating mode.
  Future<void> setFlashMode(FlashMode mode) async {
    _ensureInitialized();
    try {
      await _platform.setFlashMode(_textureId!, mode);
      value = value.copyWith(flashMode: mode);
    } catch (e) {
      value = value.copyWith(errorDescription: e.toString());
      rethrow;
    }
  }

  /// Sets continuous torch light mode and brightness level (0.0 to 1.0).
  Future<void> setTorchMode(bool enabled, {double level = 1.0}) async {
    _ensureInitialized();
    try {
      await _platform.setTorchMode(_textureId!, enabled, level: level);
      value = value.copyWith(
        torchEnabled: enabled,
        flashMode: enabled ? FlashMode.torch : FlashMode.off,
      );
    } catch (e) {
      value = value.copyWith(errorDescription: e.toString());
      rethrow;
    }
  }

  /// Configures autofocus mode.
  Future<void> setFocusMode(FocusMode mode) async {
    _ensureInitialized();
    try {
      await _platform.setFocusMode(_textureId!, mode);
      value = value.copyWith(focusMode: mode);
    } catch (e) {
      value = value.copyWith(errorDescription: e.toString());
      rethrow;
    }
  }

  /// Sets manual focus distance (0.0 represents infinity, up to maxFocusDistance for macro).
  Future<void> setFocusDistance(double distance) async {
    _ensureInitialized();
    try {
      await _platform.setFocusDistance(_textureId!, distance);
      value = value.copyWith(
        focusMode: FocusMode.manual,
        currentFocusDistance: distance,
      );
    } catch (e) {
      value = value.copyWith(errorDescription: e.toString());
      rethrow;
    }
  }

  /// Configures point of interest for autofocus and autoexposure.
  ///
  /// Normalized coordinates [point.dx] and [point.dy] range from 0.0 to 1.0.
  Future<void> setPointOfInterest(Offset point) async {
    _ensureInitialized();
    try {
      final clampedX = point.dx.clamp(0.0, 1.0);
      final clampedY = point.dy.clamp(0.0, 1.0);
      await _platform.setPointOfInterest(_textureId!, clampedX, clampedY);
    } catch (e) {
      value = value.copyWith(errorDescription: e.toString());
      rethrow;
    }
  }

  /// Sets auto or manual exposure mode.
  Future<void> setExposureMode(ExposureMode mode) async {
    _ensureInitialized();
    try {
      await _platform.setExposureMode(_textureId!, mode);
      value = value.copyWith(exposureMode: mode);
    } catch (e) {
      value = value.copyWith(errorDescription: e.toString());
      rethrow;
    }
  }

  /// Sets manual ISO sensitivity.
  Future<void> setIso(int iso) async {
    _ensureInitialized();
    final clampedIso = iso.clamp(description.minIso, description.maxIso);
    try {
      await _platform.setIso(_textureId!, clampedIso);
      value = value.copyWith(
        exposureMode: ExposureMode.manual,
        currentIso: clampedIso,
      );
    } catch (e) {
      value = value.copyWith(errorDescription: e.toString());
      rethrow;
    }
  }

  /// Sets manual exposure duration (shutter speed).
  Future<void> setExposureDuration(Duration duration) async {
    _ensureInitialized();
    final durationMicros = duration.inMicroseconds.clamp(
      description.minExposureDuration.inMicroseconds,
      description.maxExposureDuration.inMicroseconds,
    );
    try {
      await _platform.setExposureDuration(_textureId!, durationMicros);
      value = value.copyWith(
        exposureMode: ExposureMode.manual,
        currentExposureDuration: Duration(microseconds: durationMicros),
      );
    } catch (e) {
      value = value.copyWith(errorDescription: e.toString());
      rethrow;
    }
  }

  /// Adjusts exposure compensation target bias in EV.
  Future<void> setExposureBias(double bias) async {
    _ensureInitialized();
    final clampedBias = bias.clamp(
      description.minExposureBias,
      description.maxExposureBias,
    );
    try {
      await _platform.setExposureBias(_textureId!, clampedBias);
      value = value.copyWith(currentExposureBias: clampedBias);
    } catch (e) {
      value = value.copyWith(errorDescription: e.toString());
      rethrow;
    }
  }

  /// Sets white balance mode or custom Kelvin temperature.
  Future<void> setWhiteBalanceMode(
    WhiteBalanceMode mode, {
    int? temperatureKelvin,
  }) async {
    _ensureInitialized();
    try {
      await _platform.setWhiteBalanceMode(
        _textureId!,
        mode,
        temperatureKelvin: temperatureKelvin,
      );
      value = value.copyWith(whiteBalanceMode: mode);
    } catch (e) {
      value = value.copyWith(errorDescription: e.toString());
      rethrow;
    }
  }

  /// Sets the optical / digital zoom factor (e.g. 1.0, 2.0, 5.0).
  Future<void> setZoom(double zoom) async {
    _ensureInitialized();
    final clampedZoom = zoom.clamp(description.minZoom, description.maxZoom);
    try {
      await _platform.setZoom(_textureId!, clampedZoom);
      value = value.copyWith(currentZoom: clampedZoom);
    } catch (e) {
      value = value.copyWith(errorDescription: e.toString());
      rethrow;
    }
  }

  /// Sets the target frame rate in frames per second.
  Future<void> setFps(int fps) async {
    _ensureInitialized();
    try {
      await _platform.setFps(_textureId!, fps);
    } catch (e) {
      value = value.copyWith(errorDescription: e.toString());
      rethrow;
    }
  }

  /// Sets hardware video stabilization mode.
  Future<void> setStabilizationMode(StabilizationMode mode) async {
    _ensureInitialized();
    try {
      await _platform.setStabilizationMode(_textureId!, mode);
      value = value.copyWith(stabilizationMode: mode);
    } catch (e) {
      value = value.copyWith(errorDescription: e.toString());
      rethrow;
    }
  }

  void _ensureInitialized() {
    if (_isDisposed) {
      throw StateError('NativeCameraController is disposed');
    }
    if (_textureId == null || !value.isInitialized) {
      throw StateError('NativeCameraController is not initialized');
    }
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;

    await _imageStreamSubscription?.cancel();
    _imageStreamSubscription = null;

    if (_textureId != null) {
      try {
        await _platform.dispose(_textureId!);
      } catch (_) {
        // Silently ignore disposal errors during teardown
      }
      _textureId = null;
    }

    super.dispose();
  }
}
