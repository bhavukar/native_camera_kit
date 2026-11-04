# Native Camera Kit

[![Pub Version](https://img.shields.io/pub/v/native_camera_kit.svg?style=flat-square)](https://pub.dev/packages/native_camera_kit)
[![Pub Points](https://img.shields.io/pub/points/native_camera_kit?style=flat-square)](https://pub.dev/packages/native_camera_kit)
[![Platform](https://img.shields.io/badge/platform-android%20%7C%20ios-blue.svg?style=flat-square)](https://pub.dev/packages/native_camera_kit)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](https://opensource.org/licenses/MIT)

A high-performance Flutter camera plugin with direct low-level sensor access, manual ISO, shutter speed (exposure duration), manual focus distance, tap-to-focus, exposure compensation, and zero-copy raw frame buffer streaming for Android (Camera2) and iOS (AVFoundation).

---

## Features

- **Direct Low-Level Hardware Access**: Bypasses restrictive high-level abstractions to provide fine-grained manual control directly via Android Camera2 and iOS AVFoundation.
- **Manual Exposure & ISO**: Independent control over sensor sensitivity (ISO) and shutter duration down to nanoseconds / microseconds.
- **Manual Lens Focus & Tap-to-Focus**: Adjust physical lens position (infinity to macro) or tap anywhere on the preview to focus and expose on custom points of interest with smooth animations.
- **Real-Time Raw Frame Streaming**: Access uncompressed video frame buffers (`YUV_420_888` on Android, `BGRA8888` on iOS) directly in Dart for edge machine learning, TensorFlow Lite, ONNX, OpenCV, and barcode scanning.
- **Hardware-Accelerated Flutter Texture**: Direct GPU texture compositing (`FlutterTexture` on iOS, `SurfaceTexture` on Android) with zero memory copy overhead on the Dart UI thread.
- **Exposure Compensation**: Continuous EV target bias adjustments in calibrated sensor steps.
- **White Balance**: Presets for daylight, cloudy, fluorescent, incandescent, and custom Kelvin color temperatures.
- **Optical & Digital Zoom**: Smooth continuous zoom factor scaling with sensor crop region support.
- **Torch & Flash Modes**: Integrated flashlight level controls and photo capture flash settings.
- **Hardware Video Stabilization**: Select between standard, cinematic, and off modes.
- **High-Resolution Photo & Video**: Crisp still JPEG captures and hardware-encoded H.264/AAC MP4 video recording.

---

## Platform Setup

### Android

Ensure your minimum SDK is set to **24** or higher in `android/app/build.gradle.kts`:

```kotlin
android {
    defaultConfig {
        minSdk = 24
    }
}
```

Add the following permissions to your `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    <uses-permission android:name="android.permission.FLASHLIGHT" />

    <uses-feature android:name="android.hardware.camera" android:required="false" />
    <uses-feature android:name="android.hardware.camera.autofocus" android:required="false" />
</manifest>
```

### iOS

Ensure your deployment target is **iOS 13.0** or higher.

Add camera and microphone usage descriptions to your `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is required for live viewfinder preview and photo capture.</string>
<key>NSMicrophoneUsageDescription</key>
<string>Microphone access is required for video audio recording.</string>
```

---

## Getting Started

### 1. Discover Available Sensors

Query device camera hardware and inspect sensor characteristics (orientation, physical ISO range, shutter speed limits, and focus range):

```dart
import 'package:native_camera_kit/native_camera_kit.dart';

final cameras = await NativeCameraKit.availableCameras();
for (final camera in cameras) {
  print('${camera.name}: ISO ${camera.minIso}-${camera.maxIso}, position: ${camera.position}');
}
```

### 2. Initialize the Controller

```dart
final controller = NativeCameraController(
  cameras.first,
  resolutionPreset: ResolutionPreset.veryHigh,
  enableAudio: true,
);

await controller.initialize();
```

### 3. Display the Live Viewfinder

Use `NativeCameraPreview` to render the zero-copy hardware texture stream:

```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    body: NativeCameraPreview(
      controller: controller,
      fit: BoxFit.cover,
      enableTapToFocus: true, // Enables animated tap-to-focus ring
    ),
  );
}
```

---

## Low-Level Manual Controls

### Manual ISO & Shutter Speed

Lock auto-exposure and dial in custom exposure parameters:

```dart
// Set manual ISO sensitivity
await controller.setIso(400);

// Set shutter speed (e.g. 1/125s)
await controller.setExposureDuration(const Duration(microseconds: 8000));

// Return to continuous auto-exposure
await controller.setExposureMode(ExposureMode.auto);
```

### Manual Focus & Tap-to-Focus

```dart
// Set manual lens distance (0.0 = infinity, up to camera.maxFocusDistance for macro)
await controller.setFocusDistance(5.0);

// Tap anywhere on the preview using normalized coordinates (0.0 to 1.0)
await controller.setPointOfInterest(const Offset(0.5, 0.5));

// Restore continuous autofocus
await controller.setFocusMode(FocusMode.continuous);
```

### Exposure Compensation (EV)

```dart
// Step down by -1.0 EV
await controller.setExposureBias(-1.0);
```

### White Balance

```dart
// Use preset
await controller.setWhiteBalanceMode(WhiteBalanceMode.daylight);

// Or dial in custom color temperature in Kelvin
await controller.setWhiteBalanceMode(
  WhiteBalanceMode.daylight,
  temperatureKelvin: 5600,
);
```

### Zoom & Torch

```dart
// Adjust zoom factor (e.g. 2.5x)
await controller.setZoom(2.5);

// Turn on flashlight torch at 80% brightness
await controller.setTorchMode(true, level: 0.8);
```

---

## Real-Time Raw Frame Streaming (Computer Vision & ML)

Stream uncompressed planar video frames directly to Dart for real-time inference:

```dart
await controller.startImageStream((CameraImage frame) {
  print('Frame format: ${frame.format}, resolution: ${frame.width}x${frame.height}');

  for (final plane in frame.planes) {
    print('Plane buffer: ${plane.bytes.length} bytes, rowStride: ${plane.bytesPerRow}');
  }
});

// Stop streaming when done
await controller.stopImageStream();
```

---

## Photo Capture & Video Recording

```dart
// Capture high-resolution still image
final CapturedImage photo = await controller.takePicture();
print('Saved to: ${photo.path} (${photo.width}x${photo.height})');

// Record video
await controller.startVideoRecording();
await Future.delayed(const Duration(seconds: 5));
final CapturedVideo video = await controller.stopVideoRecording();
print('Video saved to: ${video.path} (${video.bytesLength} bytes)');
```

---

## API Overview

| Class | Description |
|---|---|
| `NativeCameraKit` | Static entrypoint to query `availableCameras()` across the device. |
| `NativeCameraController` | Manages camera session lifecycle, manual settings, capture, and video streaming. |
| `NativeCameraPreview` | Widget rendering hardware texture with aspect ratio scaling, front-camera mirroring, and tap-to-focus. |
| `NativeCameraDescription` | Hardware metadata: ISO boundaries, shutter speed ranges, diopter distances, and orientation. |
| `CameraImage` | Raw planar frame buffer (`yuv420` on Android, `bgra8888` on iOS) with row strides and bytes. |
| `CapturedImage` | Metadata for captured still photos (path, width, height, bytes length). |
| `CapturedVideo` | Metadata for recorded MP4 video files. |

---

## License

MIT License. See [LICENSE](LICENSE) for details.
