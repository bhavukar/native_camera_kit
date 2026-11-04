/// High-performance Flutter camera package with direct low-level sensor access,
/// manual ISO, shutter speed, focus distance, and raw frame streaming for Android & iOS.
library;

import 'src/models/camera_description.dart';
import 'src/platform/native_camera_kit_platform_interface.dart';

export 'src/controller/native_camera_controller.dart';
export 'src/models/camera_description.dart';
export 'src/models/camera_enums.dart';
export 'src/models/camera_image.dart';
export 'src/models/camera_value.dart';
export 'src/models/captured_media.dart';
export 'src/platform/native_camera_kit_platform_interface.dart';
export 'src/widgets/native_camera_preview.dart';

/// Entry point helper class for discovering and querying camera hardware.
abstract final class NativeCameraKit {
  /// Queries the device for all available camera sensors and their low-level capabilities.
  ///
  /// Returns a list of [NativeCameraDescription] instances detailing ISO ranges,
  /// shutter speed boundaries, focus distance capabilities, zoom ratios, and sensor orientation.
  static Future<List<NativeCameraDescription>> availableCameras() {
    return NativeCameraKitPlatform.instance.availableCameras();
  }
}
