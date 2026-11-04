import 'dart:typed_data';
import 'camera_enums.dart';

/// Single planar buffer belonging to a [CameraImage].
class CameraImagePlane {
  /// Raw binary pixel data of this plane.
  final Uint8List bytes;

  /// Row stride in bytes across rows in this plane.
  final int bytesPerRow;

  /// Distance between adjacent pixel samples in bytes, or null if planar.
  final int? bytesPerPixel;

  /// Width of this specific plane in pixels, or null if matches image width.
  final int? width;

  /// Height of this specific plane in pixels, or null if matches image height.
  final int? height;

  /// Creates a [CameraImagePlane].
  const CameraImagePlane({
    required this.bytes,
    required this.bytesPerRow,
    this.bytesPerPixel,
    this.width,
    this.height,
  });

  /// Deserializes a [CameraImagePlane] from raw platform data.
  factory CameraImagePlane.fromMap(Map<String, dynamic> map) {
    return CameraImagePlane(
      bytes: map['bytes'] as Uint8List? ?? Uint8List(0),
      bytesPerRow: (map['bytesPerRow'] as num?)?.toInt() ?? 0,
      bytesPerPixel: (map['bytesPerPixel'] as num?)?.toInt(),
      width: (map['width'] as num?)?.toInt(),
      height: (map['height'] as num?)?.toInt(),
    );
  }
}

/// A raw video frame emitted by the camera hardware pipeline.
///
/// Gives low-level direct access to pixel buffers (YUV 420 or BGRA 8888)
/// for real-time computer vision, machine learning, and barcode scanning.
class CameraImage {
  /// Format group describing the pixel arrangement.
  final ImageFormatGroup format;

  /// Horizontal resolution in pixels.
  final int width;

  /// Vertical resolution in pixels.
  final int height;

  /// List of image planes (e.g. Y, U, V for YUV420; single plane for BGRA).
  final List<CameraImagePlane> planes;

  /// Hardware timestamp in nanoseconds or milliseconds since epoch.
  final int timestamp;

  /// Sensor lens orientation for this frame in degrees.
  final int sensorOrientation;

  /// Creates a [CameraImage].
  const CameraImage({
    required this.format,
    required this.width,
    required this.height,
    required this.planes,
    required this.timestamp,
    required this.sensorOrientation,
  });

  /// Deserializes a [CameraImage] from raw platform event map.
  factory CameraImage.fromMap(Map<String, dynamic> map) {
    final formatStr = (map['format'] as String? ?? '').toLowerCase();
    final format = switch (formatStr) {
      'yuv420' => ImageFormatGroup.yuv420,
      'bgra8888' => ImageFormatGroup.bgra8888,
      'jpeg' => ImageFormatGroup.jpeg,
      _ => ImageFormatGroup.unknown,
    };

    final rawPlanes = (map['planes'] as List<dynamic>?) ?? [];
    final planes = rawPlanes
        .map((p) => CameraImagePlane.fromMap(Map<String, dynamic>.from(p as Map)))
        .toList();

    return CameraImage(
      format: format,
      width: (map['width'] as num?)?.toInt() ?? 0,
      height: (map['height'] as num?)?.toInt() ?? 0,
      planes: planes,
      timestamp: (map['timestamp'] as num?)?.toInt() ?? 0,
      sensorOrientation: (map['sensorOrientation'] as num?)?.toInt() ?? 0,
    );
  }
}
