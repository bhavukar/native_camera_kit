import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/camera_description.dart';
import '../models/camera_enums.dart';
import '../models/camera_image.dart';
import '../models/captured_media.dart';
import 'native_camera_kit_platform_interface.dart';

/// An implementation of [NativeCameraKitPlatform] that uses method channels.
class MethodChannelNativeCameraKit extends NativeCameraKitPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('dev.bhavuk.native_camera_kit');

  final Map<int, EventChannel> _imageEventChannels = {};

  @override
  Future<List<NativeCameraDescription>> availableCameras() async {
    final rawList = await methodChannel.invokeListMethod<Map<dynamic, dynamic>>(
      'availableCameras',
    );
    if (rawList == null) return [];
    return rawList
        .map((m) =>
            NativeCameraDescription.fromMap(Map<String, dynamic>.from(m)))
        .toList();
  }

  @override
  Future<Map<String, dynamic>> create({
    required String cameraId,
    required ResolutionPreset resolutionPreset,
    required bool enableAudio,
    required ImageFormatGroup imageFormatGroup,
  }) async {
    final result = await methodChannel.invokeMapMethod<String, dynamic>(
      'create',
      {
        'cameraId': cameraId,
        'resolutionPreset': resolutionPreset.name,
        'enableAudio': enableAudio,
        'imageFormatGroup': imageFormatGroup.name,
      },
    );
    return result ?? {};
  }

  @override
  Future<void> initialize(int textureId) async {
    await methodChannel.invokeMethod<void>(
      'initialize',
      {'textureId': textureId},
    );
  }

  @override
  Future<void> dispose(int textureId) async {
    _imageEventChannels.remove(textureId);
    await methodChannel.invokeMethod<void>(
      'dispose',
      {'textureId': textureId},
    );
  }

  @override
  Future<CapturedImage> takePicture(int textureId, {String? path}) async {
    final result = await methodChannel.invokeMapMethod<String, dynamic>(
      'takePicture',
      {
        'textureId': textureId,
        'path': path,
      },
    );
    if (result == null) {
      throw PlatformException(
        code: 'CAPTURE_FAILED',
        message: 'Native camera returned null for takePicture',
      );
    }
    return CapturedImage.fromMap(result);
  }

  @override
  Future<void> startVideoRecording(int textureId, {String? path}) async {
    await methodChannel.invokeMethod<void>(
      'startVideoRecording',
      {
        'textureId': textureId,
        'path': path,
      },
    );
  }

  @override
  Future<void> pauseVideoRecording(int textureId) async {
    await methodChannel.invokeMethod<void>(
      'pauseVideoRecording',
      {'textureId': textureId},
    );
  }

  @override
  Future<void> resumeVideoRecording(int textureId) async {
    await methodChannel.invokeMethod<void>(
      'resumeVideoRecording',
      {'textureId': textureId},
    );
  }

  @override
  Future<CapturedVideo> stopVideoRecording(int textureId) async {
    final result = await methodChannel.invokeMapMethod<String, dynamic>(
      'stopVideoRecording',
      {'textureId': textureId},
    );
    if (result == null) {
      throw PlatformException(
        code: 'RECORDING_FAILED',
        message: 'Native camera returned null for stopVideoRecording',
      );
    }
    return CapturedVideo.fromMap(result);
  }

  @override
  Future<void> setFlashMode(int textureId, FlashMode mode) async {
    await methodChannel.invokeMethod<void>(
      'setFlashMode',
      {
        'textureId': textureId,
        'mode': mode.name,
      },
    );
  }

  @override
  Future<void> setTorchMode(
    int textureId,
    bool enabled, {
    double level = 1.0,
  }) async {
    await methodChannel.invokeMethod<void>(
      'setTorchMode',
      {
        'textureId': textureId,
        'enabled': enabled,
        'level': level,
      },
    );
  }

  @override
  Future<void> setFocusMode(int textureId, FocusMode mode) async {
    await methodChannel.invokeMethod<void>(
      'setFocusMode',
      {
        'textureId': textureId,
        'mode': mode.name,
      },
    );
  }

  @override
  Future<void> setFocusDistance(int textureId, double distance) async {
    await methodChannel.invokeMethod<void>(
      'setFocusDistance',
      {
        'textureId': textureId,
        'distance': distance,
      },
    );
  }

  @override
  Future<void> setPointOfInterest(int textureId, double x, double y) async {
    await methodChannel.invokeMethod<void>(
      'setPointOfInterest',
      {
        'textureId': textureId,
        'x': x,
        'y': y,
      },
    );
  }

  @override
  Future<void> setExposureMode(int textureId, ExposureMode mode) async {
    await methodChannel.invokeMethod<void>(
      'setExposureMode',
      {
        'textureId': textureId,
        'mode': mode.name,
      },
    );
  }

  @override
  Future<void> setIso(int textureId, int iso) async {
    await methodChannel.invokeMethod<void>(
      'setIso',
      {
        'textureId': textureId,
        'iso': iso,
      },
    );
  }

  @override
  Future<void> setExposureDuration(int textureId, int durationMicros) async {
    await methodChannel.invokeMethod<void>(
      'setExposureDuration',
      {
        'textureId': textureId,
        'durationMicros': durationMicros,
      },
    );
  }

  @override
  Future<void> setExposureBias(int textureId, double bias) async {
    await methodChannel.invokeMethod<void>(
      'setExposureBias',
      {
        'textureId': textureId,
        'bias': bias,
      },
    );
  }

  @override
  Future<void> setWhiteBalanceMode(
    int textureId,
    WhiteBalanceMode mode, {
    int? temperatureKelvin,
  }) async {
    await methodChannel.invokeMethod<void>(
      'setWhiteBalanceMode',
      {
        'textureId': textureId,
        'mode': mode.name,
        'temperatureKelvin': temperatureKelvin,
      },
    );
  }

  @override
  Future<void> setZoom(int textureId, double zoom) async {
    await methodChannel.invokeMethod<void>(
      'setZoom',
      {
        'textureId': textureId,
        'zoom': zoom,
      },
    );
  }

  @override
  Future<void> setFps(int textureId, int fps) async {
    await methodChannel.invokeMethod<void>(
      'setFps',
      {
        'textureId': textureId,
        'fps': fps,
      },
    );
  }

  @override
  Future<void> setStabilizationMode(
    int textureId,
    StabilizationMode mode,
  ) async {
    await methodChannel.invokeMethod<void>(
      'setStabilizationMode',
      {
        'textureId': textureId,
        'mode': mode.name,
      },
    );
  }

  @override
  Stream<CameraImage> startImageStream(int textureId) {
    var channel = _imageEventChannels[textureId];
    if (channel == null) {
      channel = EventChannel(
        'dev.bhavuk.native_camera_kit/image_stream_$textureId',
      );
      _imageEventChannels[textureId] = channel;
    }

    return channel.receiveBroadcastStream().map((dynamic event) {
      return CameraImage.fromMap(
        Map<String, dynamic>.from(event as Map),
      );
    });
  }

  @override
  Future<void> stopImageStream(int textureId) async {
    await methodChannel.invokeMethod<void>(
      'stopImageStream',
      {'textureId': textureId},
    );
  }
}
