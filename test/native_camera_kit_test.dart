import 'package:flutter_test/flutter_test.dart';
import 'package:native_camera_kit/native_camera_kit.dart';
import 'package:native_camera_kit/src/platform/native_camera_kit_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockNativeCameraKitPlatform
    with MockPlatformInterfaceMixin
    implements NativeCameraKitPlatform {
  final List<NativeCameraDescription> mockCameras = [
    const NativeCameraDescription(
      id: '0',
      name: 'Back Camera 0',
      position: CameraPosition.back,
      sensorOrientation: 90,
      minIso: 50,
      maxIso: 3200,
      minExposureDuration: Duration(microseconds: 100),
      maxExposureDuration: Duration(microseconds: 1000000),
      minFocusDistance: 0.0,
      maxFocusDistance: 10.0,
      minZoom: 1.0,
      maxZoom: 10.0,
      minExposureBias: -2.0,
      maxExposureBias: 2.0,
      exposureBiasStep: 0.1,
      supportedFpsRanges: [FpsRange(min: 15, max: 30), FpsRange(min: 30, max: 60)],
      supportsFlash: true,
      supportsTorch: true,
      supportsManualFocus: true,
      supportsManualExposure: true,
    ),
  ];

  @override
  Future<List<NativeCameraDescription>> availableCameras() async => mockCameras;

  @override
  Future<Map<String, dynamic>> create({
    required String cameraId,
    required ResolutionPreset resolutionPreset,
    required bool enableAudio,
    required ImageFormatGroup imageFormatGroup,
  }) async {
    return {
      'textureId': 101,
      'previewWidth': 1920.0,
      'previewHeight': 1080.0,
    };
  }

  @override
  Future<void> initialize(int textureId) async {}

  @override
  Future<void> dispose(int textureId) async {}

  @override
  Future<CapturedImage> takePicture(int textureId, {String? path}) async {
    return CapturedImage(
      path: path ?? '/tmp/mock.jpg',
      width: 1920,
      height: 1080,
      bytesLength: 409600,
      mimeType: 'image/jpeg',
    );
  }

  @override
  Future<void> startVideoRecording(int textureId, {String? path}) async {}

  @override
  Future<void> pauseVideoRecording(int textureId) async {}

  @override
  Future<void> resumeVideoRecording(int textureId) async {}

  @override
  Future<CapturedVideo> stopVideoRecording(int textureId) async {
    return const CapturedVideo(
      path: '/tmp/mock.mp4',
      duration: Duration(seconds: 5),
      bytesLength: 1048576,
    );
  }

  @override
  Future<void> setFlashMode(int textureId, FlashMode mode) async {}

  @override
  Future<void> setTorchMode(int textureId, bool enabled, {double level = 1.0}) async {}

  @override
  Future<void> setFocusMode(int textureId, FocusMode mode) async {}

  @override
  Future<void> setFocusDistance(int textureId, double distance) async {}

  @override
  Future<void> setPointOfInterest(int textureId, double x, double y) async {}

  @override
  Future<void> setExposureMode(int textureId, ExposureMode mode) async {}

  @override
  Future<void> setIso(int textureId, int iso) async {}

  @override
  Future<void> setExposureDuration(int textureId, int durationMicros) async {}

  @override
  Future<void> setExposureBias(int textureId, double bias) async {}

  @override
  Future<void> setWhiteBalanceMode(int textureId, WhiteBalanceMode mode, {int? temperatureKelvin}) async {}

  @override
  Future<void> setZoom(int textureId, double zoom) async {}

  @override
  Future<void> setFps(int textureId, int fps) async {}

  @override
  Future<void> setStabilizationMode(int textureId, StabilizationMode mode) async {}

  @override
  Stream<CameraImage> startImageStream(int textureId) => const Stream.empty();

  @override
  Future<void> stopImageStream(int textureId) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final NativeCameraKitPlatform initialPlatform = NativeCameraKitPlatform.instance;

  test('MethodChannelNativeCameraKit is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelNativeCameraKit>());
  });

  test('NativeCameraKit.availableCameras queries platform interface', () async {
    final fakePlatform = MockNativeCameraKitPlatform();
    NativeCameraKitPlatform.instance = fakePlatform;

    final cameras = await NativeCameraKit.availableCameras();
    expect(cameras.length, 1);
    expect(cameras.first.id, '0');
    expect(cameras.first.name, 'Back Camera 0');
    expect(cameras.first.position, CameraPosition.back);
    expect(cameras.first.minIso, 50);
    expect(cameras.first.maxIso, 3200);
  });

  test('NativeCameraController full lifecycle and controls', () async {
    final fakePlatform = MockNativeCameraKitPlatform();
    NativeCameraKitPlatform.instance = fakePlatform;

    final controller = NativeCameraController(
      fakePlatform.mockCameras.first,
      resolutionPreset: ResolutionPreset.veryHigh,
    );

    expect(controller.value.isInitialized, isFalse);

    await controller.initialize();
    expect(controller.value.isInitialized, isTrue);
    expect(controller.textureId, 101);
    expect(controller.value.previewSize?.width, 1920.0);
    expect(controller.value.previewSize?.height, 1080.0);

    // Manual controls
    await controller.setIso(400);
    expect(controller.value.currentIso, 400);
    expect(controller.value.exposureMode, ExposureMode.manual);

    await controller.setExposureDuration(const Duration(milliseconds: 20));
    expect(controller.value.currentExposureDuration, const Duration(milliseconds: 20));

    await controller.setFocusDistance(5.0);
    expect(controller.value.currentFocusDistance, 5.0);
    expect(controller.value.focusMode, FocusMode.manual);

    await controller.setZoom(2.5);
    expect(controller.value.currentZoom, 2.5);

    await controller.setExposureBias(1.0);
    expect(controller.value.currentExposureBias, 1.0);

    await controller.setTorchMode(true);
    expect(controller.value.torchEnabled, isTrue);

    // Photo capture
    final photo = await controller.takePicture();
    expect(photo.path, isNotEmpty);
    expect(photo.width, 1920);

    // Video record
    await controller.startVideoRecording();
    expect(controller.value.isRecordingVideo, isTrue);

    final video = await controller.stopVideoRecording();
    expect(controller.value.isRecordingVideo, isFalse);
    expect(video.bytesLength, 1048576);

    // Dispose
    await controller.dispose();
    expect(controller.isDisposed, isTrue);
    expect(controller.textureId, isNull);
  });
}
