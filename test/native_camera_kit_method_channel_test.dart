import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_camera_kit/src/models/camera_enums.dart';
import 'package:native_camera_kit/src/platform/native_camera_kit_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platform = MethodChannelNativeCameraKit();
  const channel = MethodChannel('dev.bhavuk.native_camera_kit');
  final log = <MethodCall>[];

  setUp(() {
    log.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      log.add(methodCall);
      switch (methodCall.method) {
        case 'availableCameras':
          return [
            {
              'id': '0',
              'name': 'Back Camera',
              'position': 'back',
              'sensorOrientation': 90,
              'minIso': 50,
              'maxIso': 3200,
              'minExposureDurationMicros': 100,
              'maxExposureDurationMicros': 1000000,
              'minFocusDistance': 0.0,
              'maxFocusDistance': 10.0,
              'minZoom': 1.0,
              'maxZoom': 10.0,
              'minExposureBias': -2.0,
              'maxExposureBias': 2.0,
              'exposureBiasStep': 0.1,
              'supportedFpsRanges': [
                {'min': 30, 'max': 30}
              ],
              'supportsFlash': true,
              'supportsTorch': true,
              'supportsManualFocus': true,
              'supportsManualExposure': true,
            }
          ];
        case 'create':
          return {
            'textureId': 42,
            'previewWidth': 1920,
            'previewHeight': 1080,
          };
        case 'initialize':
        case 'dispose':
        case 'startVideoRecording':
        case 'pauseVideoRecording':
        case 'resumeVideoRecording':
        case 'setFlashMode':
        case 'setTorchMode':
        case 'setFocusMode':
        case 'setFocusDistance':
        case 'setPointOfInterest':
        case 'setExposureMode':
        case 'setIso':
        case 'setExposureDuration':
        case 'setExposureBias':
        case 'setWhiteBalanceMode':
        case 'setZoom':
        case 'setFps':
        case 'setStabilizationMode':
        case 'stopImageStream':
          return null;
        case 'takePicture':
          return {
            'path': '/tmp/test.jpg',
            'width': 1920,
            'height': 1080,
            'bytesLength': 12345,
            'mimeType': 'image/jpeg',
          };
        case 'stopVideoRecording':
          return {
            'path': '/tmp/test.mp4',
            'durationMs': 3000,
            'bytesLength': 654321,
          };
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('availableCameras parses list properly', () async {
    final cameras = await platform.availableCameras();
    expect(cameras.length, 1);
    expect(cameras.first.id, '0');
    expect(cameras.first.position, CameraPosition.back);
    expect(log.single.method, 'availableCameras');
  });

  test('create camera creates texture map', () async {
    final res = await platform.create(
      cameraId: '0',
      resolutionPreset: ResolutionPreset.veryHigh,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    expect(res['textureId'], 42);
    expect(log.single.method, 'create');
  });

  test('takePicture returns CapturedImage', () async {
    final photo = await platform.takePicture(42, path: '/custom.jpg');
    expect(photo.path, '/tmp/test.jpg');
    expect(photo.width, 1920);
    expect(log.single.method, 'takePicture');
    expect(log.single.arguments['textureId'], 42);
  });

  test('stopVideoRecording returns CapturedVideo', () async {
    final video = await platform.stopVideoRecording(42);
    expect(video.path, '/tmp/test.mp4');
    expect(video.duration, const Duration(seconds: 3));
    expect(video.bytesLength, 654321);
  });
}
