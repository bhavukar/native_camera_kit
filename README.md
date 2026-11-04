<p align="center">
  <h1 align="center">📷 Native Camera Kit</h1>
  <p align="center">
    <strong>Ultra-low-latency, direct hardware camera pipeline for Flutter on Android & iOS.</strong>
  </p>
  <p align="center">
    <a href="https://pub.dev/packages/native_camera_kit"><img src="https://img.shields.io/pub/v/native_camera_kit.svg?style=flat-square&color=blue" alt="Pub Version"></a>
    <a href="https://pub.dev/packages/native_camera_kit"><img src="https://img.shields.io/pub/points/native_camera_kit?style=flat-square&color=2E8B57" alt="Pub Points"></a>
    <a href="https://github.com/bhavukar/native_camera_kit/blob/main/LICENSE"><img src="https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square" alt="License: MIT"></a>
    <a href="https://github.com/bhavukar/native_camera_kit/actions"><img src="https://img.shields.io/github/actions/workflow/status/bhavukar/native_camera_kit/ci.yml?branch=main&style=flat-square&label=CI" alt="CI"></a>
    <a href="https://pub.dev/packages/native_camera_kit"><img src="https://img.shields.io/badge/platform-android%20%7C%20ios-blue.svg?style=flat-square" alt="Platform"></a>
  </p>
</p>

---

## ⚡ Why Native Camera Kit?

Most Flutter camera packages wrap high-level system components that obscure low-level hardware knobs. **`native_camera_kit`** bridges directly to **Android Camera2** and **iOS AVFoundation**, giving you raw access to:

1. **Independent Manual Exposure**: Dial in exact ISO values and shutter speed down to the microsecond.
2. **True Manual Focus**: Move the physical lens element from infinity (`0.0`) to extreme macro directly by diopter/position.
3. **Zero-Copy GPU Compositing**: Video preview renders directly via hardware surfaces (`SurfaceTexture` / `FlutterTexture`), leaving your Dart UI thread completely free.
4. **Planar Raw Video Streaming**: Receive uncompressed `YUV_420_888` (Android) and `BGRA8888` (iOS) frame buffers with pixel strides for real-time edge AI, TensorFlow Lite, ONNX, and OpenCV.

---

## 📊 Feature Matrix & Comparison

| Feature | `native_camera_kit` | Official `camera` | `camerawesome` |
|---|:---:|:---:|:---:|
| **Direct Camera2 / AVFoundation** | ✅ Full Native | ⚠️ Partial | ⚠️ Partial |
| **Exact ISO Override** | ✅ Manual int | ❌ Auto-biased | ❌ Limited |
| **Microsecond Shutter Speed** | ✅ Manual duration | ❌ Auto-only | ❌ Auto-only |
| **Physical Lens Distance (Macro/Inf)** | ✅ Full control | ❌ Lock only | ❌ Lock only |
| **Zero-Copy Flutter Texture** | ✅ Hardware GPU | ✅ Texture | ✅ Texture |
| **Raw Planar Frame Buffers (ML/CV)** | ✅ YUV420 & BGRA | ⚠️ Copies | ⚠️ Copies |
| **Animated Tap-to-Focus Indicator** | ✅ Built-in | ❌ Manual | ❌ Manual |
| **Custom Kelvin White Balance** | ✅ 2000K–10000K | ⚠️ Presets only | ⚠️ Presets only |
| **Hardware Video Stabilization** | ✅ Standard & Cinematic | ⚠️ Basic | ⚠️ Basic |
| **Pub.dev Dry-Run Warnings** | **0 Warnings** | — | — |

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Your Flutter App                       │
│           (NativeCameraPreview / Manual Sliders / ML)       │
└──────────────────────────────┬──────────────────────────────┘
                               │
            ┌──────────────────┴──────────────────┐
            ▼                                     ▼
┌───────────────────────────┐         ┌───────────────────────┐
│  MethodChannel & Events   │         │  Flutter Texture API  │
│  (Settings & Raw Frames)  │         │  (Direct GPU Surface) │
└───────────┬───────────────┘         └───────────┬───────────┘
            │                                     │
    ┌───────┴─────────────────┐           ┌───────┴───────────────┐
    ▼                         ▼           ▼                       ▼
┌─────────────────┐   ┌─────────────────┐ ┌───────────────┐   ┌───────────────┐
│ Android Camera2 │   │ iOS AVFoundation│ │ Android Surface│   │ iOS Metal     │
│ Pipeline        │   │ Pipeline        │ │ Texture       │   │ CVPixelBuffer │
└─────────────────┘   └─────────────────┘ └───────────────┘   └───────────────┘
```

---

## 🚀 Installation

Add `native_camera_kit` to your `pubspec.yaml`:

```yaml
dependencies:
  native_camera_kit: ^0.0.1
```

Or run:

```bash
flutter pub add native_camera_kit
```

---

## ⚙️ Platform Configuration

### 🤖 Android Setup

1. Set your `minSdk` to **24** or higher in `android/app/build.gradle.kts`:

```kotlin
android {
    defaultConfig {
        minSdk = 24
    }
}
```

2. Add camera and audio permissions to `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    <uses-permission android:name="android.permission.FLASHLIGHT" />

    <uses-feature android:name="android.hardware.camera" android:required="false" />
    <uses-feature android:name="android.hardware.camera.autofocus" android:required="false" />
    <uses-feature android:name="android.hardware.camera.flash" android:required="false" />
</manifest>
```

---

### 🍏 iOS Setup

1. Ensure your deployment target is **iOS 13.0** or higher in `ios/Podfile`:

```ruby
platform :ios, '13.0'
```

2. Add usage descriptions to `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is required for real-time preview and photo capture.</string>
<key>NSMicrophoneUsageDescription</key>
<string>Microphone access is required for video sound recording.</string>
```

---

## 💡 Quick Start

```dart
import 'package:flutter/material.dart';
import 'package:native_camera_kit/native_camera_kit.dart';

void main() => runApp(const MaterialApp(home: CameraApp()));

class CameraApp extends StatefulWidget {
  const CameraApp({super.key});

  @override
  State<CameraApp> createState() => _CameraAppState();
}

class _CameraAppState extends State<CameraApp> {
  NativeCameraController? _controller;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    // 1. Enumerate available hardware sensors
    final cameras = await NativeCameraKit.availableCameras();
    if (cameras.isEmpty) return;

    // 2. Create the controller
    final controller = NativeCameraController(
      cameras.first,
      resolutionPreset: ResolutionPreset.veryHigh,
      enableAudio: true,
    );

    // 3. Initialize hardware session
    await controller.initialize();

    setState(() => _controller = controller);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // 4. Render zero-copy hardware viewfinder
    return Scaffold(
      body: NativeCameraPreview(
        controller: _controller!,
        fit: BoxFit.cover,
        enableTapToFocus: true, // Smooth animated tap-to-focus ring
      ),
    );
  }
}
```

---

## 🛠️ Pro Manual Recipes

### 🌌 1. Long Exposure / Astrophotography
Lock auto-exposure and set low ISO with a long shutter duration to eliminate noise and capture trails:

```dart
// Lock exposure to manual mode
await controller.setExposureMode(ExposureMode.manual);

// Clean sensor sensitivity
await controller.setIso(100);

// Long shutter speed (e.g. 1/2 second = 500,000 microseconds)
await controller.setExposureDuration(const Duration(microseconds: 500000));
```

### ⚡ 2. Action Freeze / High-Speed Photography
Freeze fast motion without motion blur:

```dart
// Fast shutter speed (1/2000s = 500 microseconds)
await controller.setExposureDuration(const Duration(microseconds: 500));

// Compensate with higher ISO
await controller.setIso(1600);
```

### 🔍 3. Macro Photography
Override autofocus and drive the physical lens motor directly to its minimum focusing distance:

```dart
// Set lens to maximum close-up diopter
final maxMacro = controller.description.maxFocusDistance;
await controller.setFocusDistance(maxMacro);
```

### 🎯 4. Tap-to-Focus Point of Interest
Specify custom focus & metering coordinates normalized between `0.0` and `1.0`:

```dart
// Center of frame
await controller.setPointOfInterest(const Offset(0.5, 0.5));
```

### 🌡️ 5. Custom Kelvin White Balance
Dial in the exact scene color temperature:

```dart
// Golden hour warmth (~3200K)
await controller.setWhiteBalanceMode(
  WhiteBalanceMode.incandescent,
  temperatureKelvin: 3200,
);

// Cool daylight (~6500K)
await controller.setWhiteBalanceMode(
  WhiteBalanceMode.cloudy,
  temperatureKelvin: 6500,
);
```

---

## 🧠 Real-Time Frame Streaming (AI / Computer Vision)

Direct access to planar uncompressed pixel bytes without capturing files to disk:

```dart
await controller.startImageStream((CameraImage frame) {
  // Format is yuv420 on Android, bgra8888 on iOS
  print('Frame format: ${frame.format.name}, resolution: ${frame.width}x${frame.height}');

  for (int i = 0; i < frame.planes.length; i++) {
    final plane = frame.planes[i];
    print('Plane $i: ${plane.bytes.length} bytes, rowStride: ${plane.bytesPerRow}');
  }

  // Feed plane.bytes into TensorFlow Lite, ONNX, ML Kit, or OpenCV
});

// Stop streaming when completed
await controller.stopImageStream();
```

---

## 📸 Still Capture & Video Recording

```dart
// High-Resolution Photo Capture
final CapturedImage photo = await controller.takePicture();
print('Saved to: ${photo.path} (${photo.width}x${photo.height}, ${photo.bytesLength} bytes)');

// Hardware-Encoded Video Recording
await controller.startVideoRecording();
await Future.delayed(const Duration(seconds: 10));

// Pause & Resume during recording
await controller.pauseVideoRecording();
await Future.delayed(const Duration(seconds: 2));
await controller.resumeVideoRecording();

// Stop recording
final CapturedVideo video = await controller.stopVideoRecording();
print('Saved video to: ${video.path} (${video.bytesLength} bytes)');
```

---

## 📱 Interactive Example App

The included `example/` project features a full-blown manual camera rig:
- **Real-Time HUD**: Displays live ISO, shutter speed, zoom ratio, exposure bias, and live streaming FPS counter.
- **Physical Sliders**: Smooth sliders for ISO, exposure duration, focus distance, and zoom.
- **Camera Switcher**: Easily toggle between Back Wide, Front Selfie, Ultra-Wide, and Telephoto lenses.
- **Capture Review**: Live thumbnail preview of the last captured photo or recorded video.

To run the example app:

```bash
cd example
flutter run
```

---

## 📖 API Reference

| Class | Description |
|---|---|
| `NativeCameraKit` | Static methods to query `availableCameras()`. |
| `NativeCameraController` | Controls session lifecycle, manual settings, capture, and video. |
| `NativeCameraPreview` | Hardware texture widget with aspect ratio scaling, front mirror, and tap-to-focus ring. |
| `NativeCameraDescription` | Hardware metadata: ISO boundaries, shutter speed ranges, diopter distances, and orientation. |
| `CameraImage` | Raw planar frame buffer (`yuv420` / `bgra8888`) with row strides and bytes. |
| `CameraImagePlane` | Individual planar byte buffer with `bytesPerRow` and `bytesPerPixel`. |
| `NativeCameraValue` | Observable camera state (`isInitialized`, `isRecordingVideo`, `currentIso`, etc.). |
| `CapturedImage` | Metadata for saved high-resolution photos. |
| `CapturedVideo` | Metadata for recorded MP4 video files. |

---

## 🤝 Contributing

Contributions, bug reports, and pull requests are welcome!

1. Fork the repo.
2. Create your branch (`git checkout -b feature/amazing-feature`).
3. Commit your changes (`git commit -m 'feat: add amazing feature'`).
4. Push to the branch (`git push origin feature/amazing-feature`).
5. Open a Pull Request.

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
