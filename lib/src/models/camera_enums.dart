/// Common enumerations for low-level camera configuration and state.
library;

/// Facing direction / physical location of the camera sensor.
enum CameraPosition {
  /// Back facing camera (primary world-facing sensor).
  back,

  /// Front facing camera (selfie sensor).
  front,

  /// External camera (e.g. USB or connected accessory).
  external,
}

/// Target resolution preset for preview and video streaming.
enum ResolutionPreset {
  /// 352x288 on Android, 352x288 on iOS.
  low,

  /// 720x480 on Android, 640x480 on iOS.
  medium,

  /// 1280x720 (720p).
  high,

  /// 1920x1080 (1080p Full HD).
  veryHigh,

  /// 3840x2160 (4K UHD).
  ultraHigh,

  /// Highest available sensor resolution.
  max,
}

/// Camera autofocus and manual focus modes.
enum FocusMode {
  /// Continuous autofocus driven by the camera pipeline.
  auto,

  /// Autofocus locked at current position.
  locked,

  /// Continuous picture autofocus.
  continuous,

  /// Fully manual lens distance control.
  manual,
}

/// Camera auto-exposure and manual exposure modes.
enum ExposureMode {
  /// Continuous auto-exposure driven by the camera pipeline.
  auto,

  /// Exposure locked at current parameters.
  locked,

  /// Continuous exposure adjustment.
  continuous,

  /// Fully manual exposure (manual ISO and manual shutter speed).
  manual,
}

/// White balance adjustment modes.
enum WhiteBalanceMode {
  /// Automatic white balance.
  auto,

  /// Locked at current white balance gains.
  locked,

  /// Tuned for incandescent / tungsten indoor lighting (~2700K-3000K).
  incandescent,

  /// Tuned for fluorescent office lighting (~4000K-4500K).
  fluorescent,

  /// Tuned for direct sunny daylight (~5200K-5500K).
  daylight,

  /// Tuned for overcast / cloudy skies (~6000K-6500K).
  cloudy,

  /// Tuned for open shade (~7000K-8000K).
  shade,

  /// Tuned for dusk / twilight.
  twilight,
}

/// Flash operating modes for still capture.
enum FlashMode {
  /// Flash is never triggered.
  off,

  /// Flash is automatically fired when scene luminance is low.
  auto,

  /// Flash is fired for every photo capture.
  always,

  /// Torch LED is continuously turned on.
  torch,
}

/// Hardware video stabilization modes.
enum StabilizationMode {
  /// Stabilization disabled for lowest processing latency.
  off,

  /// Standard electronic/optical stabilization.
  standard,

  /// Cinematic stabilization (iOS cinematic / Android OIS + EIS).
  cinematic,

  /// System default stabilization mode.
  auto,
}

/// Pixel format groups for raw image streaming.
enum ImageFormatGroup {
  /// YUV 420 (planar or semi-planar, Android YUV_420_888).
  yuv420,

  /// 32-bit BGRA format (iOS kCVPixelFormatType_32BGRA).
  bgra8888,

  /// Compressed JPEG frames.
  jpeg,

  /// Unrecognized or platform-specific format.
  unknown,
}
