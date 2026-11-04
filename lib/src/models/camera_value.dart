import 'dart:ui';
import 'camera_enums.dart';

/// Current state and runtime sensor values of a [NativeCameraController].
class NativeCameraValue {
  /// Whether the native camera pipeline has been successfully initialized.
  final bool isInitialized;

  /// Whether video is currently being recorded to disk.
  final bool isRecordingVideo;

  /// Whether video recording is currently paused.
  final bool isRecordingPaused;

  /// Whether a high-resolution photo is currently being captured.
  final bool isTakingPicture;

  /// Whether raw video frames are currently being streamed to Dart listeners.
  final bool isStreamingImages;

  /// Resolved dimensions of the camera preview stream.
  final Size? previewSize;

  /// Active flash mode.
  final FlashMode flashMode;

  /// Active exposure mode (auto, manual, etc.).
  final ExposureMode exposureMode;

  /// Active focus mode (auto, continuous, manual, etc.).
  final FocusMode focusMode;

  /// Active white balance mode.
  final WhiteBalanceMode whiteBalanceMode;

  /// Active hardware video stabilization mode.
  final StabilizationMode stabilizationMode;

  /// Currently configured ISO sensitivity, or null if on full auto.
  final int? currentIso;

  /// Currently configured shutter speed / exposure duration, or null if on auto.
  final Duration? currentExposureDuration;

  /// Currently configured manual focus distance, or null if on auto.
  final double? currentFocusDistance;

  /// Currently configured exposure compensation bias in EV.
  final double currentExposureBias;

  /// Currently configured optical/digital zoom factor.
  final double currentZoom;

  /// Whether torch light is currently enabled.
  final bool torchEnabled;

  /// Description of any native error that occurred during camera operation.
  final String? errorDescription;

  /// Creates a [NativeCameraValue].
  const NativeCameraValue({
    this.isInitialized = false,
    this.isRecordingVideo = false,
    this.isRecordingPaused = false,
    this.isTakingPicture = false,
    this.isStreamingImages = false,
    this.previewSize,
    this.flashMode = FlashMode.auto,
    this.exposureMode = ExposureMode.auto,
    this.focusMode = FocusMode.auto,
    this.whiteBalanceMode = WhiteBalanceMode.auto,
    this.stabilizationMode = StabilizationMode.auto,
    this.currentIso,
    this.currentExposureDuration,
    this.currentFocusDistance,
    this.currentExposureBias = 0.0,
    this.currentZoom = 1.0,
    this.torchEnabled = false,
    this.errorDescription,
  });

  /// Uninitialized camera value instance.
  static const uninitialized = NativeCameraValue();

  /// Aspect ratio of the preview stream (width / height) in landscape, or 1.0 if not ready.
  double get aspectRatio {
    if (previewSize == null || previewSize!.height == 0) return 1.0;
    return previewSize!.width / previewSize!.height;
  }

  /// Copies this value with updated fields.
  NativeCameraValue copyWith({
    bool? isInitialized,
    bool? isRecordingVideo,
    bool? isRecordingPaused,
    bool? isTakingPicture,
    bool? isStreamingImages,
    Size? previewSize,
    FlashMode? flashMode,
    ExposureMode? exposureMode,
    FocusMode? focusMode,
    WhiteBalanceMode? whiteBalanceMode,
    StabilizationMode? stabilizationMode,
    int? currentIso,
    Duration? currentExposureDuration,
    double? currentFocusDistance,
    double? currentExposureBias,
    double? currentZoom,
    bool? torchEnabled,
    String? errorDescription,
  }) {
    return NativeCameraValue(
      isInitialized: isInitialized ?? this.isInitialized,
      isRecordingVideo: isRecordingVideo ?? this.isRecordingVideo,
      isRecordingPaused: isRecordingPaused ?? this.isRecordingPaused,
      isTakingPicture: isTakingPicture ?? this.isTakingPicture,
      isStreamingImages: isStreamingImages ?? this.isStreamingImages,
      previewSize: previewSize ?? this.previewSize,
      flashMode: flashMode ?? this.flashMode,
      exposureMode: exposureMode ?? this.exposureMode,
      focusMode: focusMode ?? this.focusMode,
      whiteBalanceMode: whiteBalanceMode ?? this.whiteBalanceMode,
      stabilizationMode: stabilizationMode ?? this.stabilizationMode,
      currentIso: currentIso ?? this.currentIso,
      currentExposureDuration:
          currentExposureDuration ?? this.currentExposureDuration,
      currentFocusDistance: currentFocusDistance ?? this.currentFocusDistance,
      currentExposureBias: currentExposureBias ?? this.currentExposureBias,
      currentZoom: currentZoom ?? this.currentZoom,
      torchEnabled: torchEnabled ?? this.torchEnabled,
      errorDescription: errorDescription ?? this.errorDescription,
    );
  }

  @override
  String toString() =>
      'NativeCameraValue(initialized: $isInitialized, preview: $previewSize, zoom: $currentZoom, ISO: $currentIso)';
}
