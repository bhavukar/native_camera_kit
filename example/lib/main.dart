import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:native_camera_kit/native_camera_kit.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NativeCameraExampleApp());
}

/// The root example application.
class NativeCameraExampleApp extends StatelessWidget {
  /// Creates the root application.
  const NativeCameraExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Native Camera Kit Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF101014),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFFB800),
          surface: Color(0xFF18181E),
        ),
      ),
      home: const CameraScreen(),
    );
  }
}

/// Main camera viewfinder screen featuring low-level manual sensor controls.
class CameraScreen extends StatefulWidget {
  /// Creates the camera viewfinder screen.
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  List<NativeCameraDescription> _cameras = [];
  NativeCameraController? _controller;
  int _selectedCameraIndex = 0;
  bool _isLoading = true;
  String? _errorMessage;

  // Stream stats
  int _streamedFrameCount = 0;
  double _streamFps = 0.0;
  DateTime? _lastFpsCheck;
  int _framesSinceLastCheck = 0;

  // Media capture cache
  CapturedImage? _lastCapturedImage;
  CapturedVideo? _lastCapturedVideo;

  // Active manual controls
  double _currentZoom = 1.0;
  int? _manualIso;
  int? _manualShutterMicros;
  double? _manualFocusDist;
  double _exposureBias = 0.0;
  WhiteBalanceMode _wbMode = WhiteBalanceMode.auto;

  @override
  void initState() {
    super.initState();
    _loadCamerasAndInitialize();
  }

  Future<void> _loadCamerasAndInitialize() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final cameras = await NativeCameraKit.availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No camera sensors found on this device.';
        });
        return;
      }

      _cameras = cameras;
      await _initializeControllerForIndex(0);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to discover cameras: $e';
      });
    }
  }

  Future<void> _initializeControllerForIndex(int index) async {
    if (index < 0 || index >= _cameras.length) return;

    final oldController = _controller;
    _controller = null;
    await oldController?.dispose();

    final desc = _cameras[index];
    final controller = NativeCameraController(
      desc,
      resolutionPreset: ResolutionPreset.veryHigh,
      enableAudio: true,
      imageFormatGroup: Platform.isIOS
          ? ImageFormatGroup.bgra8888
          : ImageFormatGroup.yuv420,
    );

    try {
      await controller.initialize();
      if (!mounted) return;

      setState(() {
        _selectedCameraIndex = index;
        _controller = controller;
        _isLoading = false;
        _currentZoom = desc.minZoom;
        _manualIso = null;
        _manualShutterMicros = null;
        _manualFocusDist = null;
        _exposureBias = 0.0;
        _wbMode = WhiteBalanceMode.auto;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to initialize camera ${desc.name}: $e';
      });
    }
  }

  void _toggleImageStreaming() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (controller.value.isStreamingImages) {
      await controller.stopImageStream();
      setState(() {
        _streamFps = 0.0;
        _framesSinceLastCheck = 0;
      });
    } else {
      _lastFpsCheck = DateTime.now();
      _framesSinceLastCheck = 0;
      _streamedFrameCount = 0;

      await controller.startImageStream((frame) {
        _streamedFrameCount++;
        _framesSinceLastCheck++;

        final now = DateTime.now();
        final elapsed = now.difference(_lastFpsCheck ?? now).inMilliseconds;
        if (elapsed >= 1000) {
          if (mounted) {
            setState(() {
              _streamFps = (_framesSinceLastCheck * 1000.0) / elapsed;
              _framesSinceLastCheck = 0;
              _lastFpsCheck = now;
            });
          }
        }
      });
      setState(() {});
    }
  }

  Future<void> _capturePhoto() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    try {
      final photo = await controller.takePicture();
      setState(() {
        _lastCapturedImage = photo;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Photo saved: ${photo.width}x${photo.height} (${(photo.bytesLength / 1024).toStringAsFixed(1)} KB)'),
          backgroundColor: const Color(0xFF22222A),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Capture failed: $e')),
      );
    }
  }

  Future<void> _toggleVideoRecording() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (controller.value.isRecordingVideo) {
      try {
        final video = await controller.stopVideoRecording();
        setState(() {
          _lastCapturedVideo = video;
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Video saved: ${(video.bytesLength / 1024 / 1024).toStringAsFixed(2)} MB'),
            backgroundColor: const Color(0xFF22222A),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Stop record error: $e')),
        );
      }
    } else {
      try {
        await controller.startVideoRecording();
        setState(() {});
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Start record error: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFFFFB800)),
              SizedBox(height: 16),
              Text('Accessing low-level camera sensor...'),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null || _controller == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                const SizedBox(height: 12),
                Text(_errorMessage ?? 'Camera error', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadCamerasAndInitialize,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final controller = _controller!;
    final desc = controller.description;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar with Camera Switcher and Telemetry
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _selectedCameraIndex,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF1E1E26),
                        items: List.generate(_cameras.length, (i) {
                          final c = _cameras[i];
                          return DropdownMenuItem<int>(
                            value: i,
                            child: Text(
                              '${c.name} (${c.position.name})',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          );
                        }),
                        onChanged: (index) {
                          if (index != null && index != _selectedCameraIndex) {
                            _initializeControllerForIndex(index);
                          }
                        },
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      controller.value.torchEnabled ? Icons.flash_on : Icons.flash_off,
                      color: controller.value.torchEnabled ? const Color(0xFFFFB800) : Colors.white70,
                    ),
                    onPressed: () {
                      controller.setTorchMode(!controller.value.torchEnabled);
                    },
                  ),
                ],
              ),
            ),

            // Live Preview Viewfinder with Tap to Focus
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    NativeCameraPreview(
                      controller: controller,
                      fit: BoxFit.cover,
                      enableTapToFocus: true,
                    ),

                    // HUD Overlay with live sensor parameters
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ISO: ${_manualIso ?? "AUTO"}  |  SHTR: ${_manualShutterMicros != null ? "1/${(1000000 / _manualShutterMicros!).round()}s" : "AUTO"}',
                              style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFFFFB800)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'ZOOM: ${_currentZoom.toStringAsFixed(1)}x  |  EV: ${_exposureBias >= 0 ? "+${_exposureBias.toStringAsFixed(1)}" : _exposureBias.toStringAsFixed(1)}',
                              style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.white70),
                            ),
                            if (controller.value.isStreamingImages) ...[
                              const SizedBox(height: 2),
                              Text(
                                'STREAM: ${_streamFps.toStringAsFixed(1)} FPS  ($_streamedFrameCount frames)',
                                style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.greenAccent),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    // Recording indicator banner
                    if (controller.value.isRecordingVideo)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.fiber_manual_record, size: 12, color: Colors.white),
                              SizedBox(width: 4),
                              Text('REC', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Low-Level Manual Controls Dashboard
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFF16161C),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Manual ISO Slider
                  Row(
                    children: [
                      const SizedBox(width: 50, child: Text('ISO', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                      Expanded(
                        child: Slider(
                          value: (_manualIso ?? desc.minIso).toDouble().clamp(desc.minIso.toDouble(), desc.maxIso.toDouble()),
                          min: desc.minIso.toDouble(),
                          max: desc.maxIso.toDouble(),
                          divisions: 40,
                          label: _manualIso != null ? '$_manualIso' : 'AUTO',
                          activeColor: const Color(0xFFFFB800),
                          onChanged: (val) {
                            final isoVal = val.round();
                            setState(() => _manualIso = isoVal);
                            controller.setIso(isoVal);
                          },
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() => _manualIso = null);
                          controller.setExposureMode(ExposureMode.auto);
                        },
                        child: Text(_manualIso == null ? 'AUTO' : 'RESET', style: const TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),

                  // Manual Shutter Speed Slider
                  Row(
                    children: [
                      const SizedBox(width: 50, child: Text('SHUTTER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                      Expanded(
                        child: Slider(
                          value: (_manualShutterMicros ?? 10000).toDouble().clamp(
                                desc.minExposureDuration.inMicroseconds.toDouble(),
                                desc.maxExposureDuration.inMicroseconds.toDouble(),
                              ),
                          min: desc.minExposureDuration.inMicroseconds.toDouble(),
                          max: desc.maxExposureDuration.inMicroseconds.toDouble(),
                          divisions: 50,
                          activeColor: const Color(0xFFFFB800),
                          onChanged: (val) {
                            final micros = val.round();
                            setState(() => _manualShutterMicros = micros);
                            controller.setExposureDuration(Duration(microseconds: micros));
                          },
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() => _manualShutterMicros = null);
                          controller.setExposureMode(ExposureMode.auto);
                        },
                        child: Text(_manualShutterMicros == null ? 'AUTO' : 'RESET', style: const TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),

                  // Manual Focus Distance Slider
                  Row(
                    children: [
                      const SizedBox(width: 50, child: Text('FOCUS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                      Expanded(
                        child: Slider(
                          value: (_manualFocusDist ?? 0.0).clamp(0.0, desc.maxFocusDistance),
                          min: 0.0,
                          max: desc.maxFocusDistance > 0.0 ? desc.maxFocusDistance : 1.0,
                          activeColor: const Color(0xFFFFB800),
                          onChanged: (val) {
                            setState(() => _manualFocusDist = val);
                            controller.setFocusDistance(val);
                          },
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() => _manualFocusDist = null);
                          controller.setFocusMode(FocusMode.auto);
                        },
                        child: Text(_manualFocusDist == null ? 'AUTO' : 'RESET', style: const TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),

                  // White Balance Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _wbChip('Auto', WhiteBalanceMode.auto),
                        _wbChip('Daylight', WhiteBalanceMode.daylight),
                        _wbChip('Cloudy', WhiteBalanceMode.cloudy),
                        _wbChip('Incandescent', WhiteBalanceMode.incandescent),
                        _wbChip('Fluorescent', WhiteBalanceMode.fluorescent),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Action Buttons Row: Stream, Photo Shutter, Video Record
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Thumbnail of last capture
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF22222C),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white24),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _lastCapturedImage != null
                            ? Image.file(
                                File(_lastCapturedImage!.path),
                                fit: BoxFit.cover,
                              )
                            : (_lastCapturedVideo != null
                                ? const Icon(Icons.videocam, size: 20, color: Colors.white70)
                                : const Icon(Icons.photo, size: 20, color: Colors.white38)),
                      ),

                      // Raw Stream Toggle
                      IconButton(
                        icon: Icon(
                          controller.value.isStreamingImages ? Icons.sensors : Icons.sensors_off,
                          color: controller.value.isStreamingImages ? Colors.greenAccent : Colors.white60,
                          size: 28,
                        ),
                        tooltip: 'Raw Frame Streaming',
                        onPressed: _toggleImageStreaming,
                      ),

                      // Still Photo Shutter Button
                      GestureDetector(
                        onTap: _capturePhoto,
                        child: Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            color: Colors.transparent,
                          ),
                          child: Center(
                            child: Container(
                              width: 54,
                              height: 54,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Video Record Toggle Button
                      IconButton(
                        icon: Icon(
                          controller.value.isRecordingVideo ? Icons.stop_circle : Icons.videocam,
                          color: controller.value.isRecordingVideo ? Colors.redAccent : Colors.white60,
                          size: 32,
                        ),
                        tooltip: 'Record Video',
                        onPressed: _toggleVideoRecording,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _wbChip(String label, WhiteBalanceMode mode) {
    final isSelected = _wbMode == mode;
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: FilterChip(
        label: Text(label, style: const TextStyle(fontSize: 11)),
        selected: isSelected,
        backgroundColor: const Color(0xFF22222C),
        selectedColor: const Color(0xFFFFB800),
        onSelected: (selected) {
          if (selected) {
            setState(() => _wbMode = mode);
            _controller?.setWhiteBalanceMode(mode);
          }
        },
      ),
    );
  }
}
