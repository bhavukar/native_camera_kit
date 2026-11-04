/// Result of a high-resolution still photo capture.
class CapturedImage {
  /// File path where the captured image file is saved.
  final String path;

  /// Width in pixels.
  final int width;

  /// Height in pixels.
  final int height;

  /// File size in bytes.
  final int bytesLength;

  /// MIME type (e.g. 'image/jpeg' or 'image/png').
  final String mimeType;

  /// Creates a [CapturedImage].
  const CapturedImage({
    required this.path,
    required this.width,
    required this.height,
    required this.bytesLength,
    required this.mimeType,
  });

  /// Deserializes a [CapturedImage] from a map.
  factory CapturedImage.fromMap(Map<String, dynamic> map) {
    return CapturedImage(
      path: map['path'] as String? ?? '',
      width: (map['width'] as num?)?.toInt() ?? 0,
      height: (map['height'] as num?)?.toInt() ?? 0,
      bytesLength: (map['bytesLength'] as num?)?.toInt() ?? 0,
      mimeType: map['mimeType'] as String? ?? 'image/jpeg',
    );
  }

  /// Converts this result to a map.
  Map<String, dynamic> toMap() => {
        'path': path,
        'width': width,
        'height': height,
        'bytesLength': bytesLength,
        'mimeType': mimeType,
      };

  @override
  String toString() =>
      'CapturedImage(path: $path, ${width}x$height, $bytesLength bytes)';
}

/// Result of a hardware-encoded video recording session.
class CapturedVideo {
  /// File path where the video recording is saved.
  final String path;

  /// Duration of the recording if available.
  final Duration? duration;

  /// File size in bytes.
  final int bytesLength;

  /// Creates a [CapturedVideo].
  const CapturedVideo({
    required this.path,
    this.duration,
    required this.bytesLength,
  });

  /// Deserializes a [CapturedVideo] from a map.
  factory CapturedVideo.fromMap(Map<String, dynamic> map) {
    final durationMs = (map['durationMs'] as num?)?.toInt();
    return CapturedVideo(
      path: map['path'] as String? ?? '',
      duration: durationMs != null ? Duration(milliseconds: durationMs) : null,
      bytesLength: (map['bytesLength'] as num?)?.toInt() ?? 0,
    );
  }

  /// Converts this result to a map.
  Map<String, dynamic> toMap() => {
        'path': path,
        'durationMs': duration?.inMilliseconds,
        'bytesLength': bytesLength,
      };

  @override
  String toString() =>
      'CapturedVideo(path: $path, duration: $duration, $bytesLength bytes)';
}
