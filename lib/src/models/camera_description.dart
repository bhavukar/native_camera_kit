import 'camera_enums.dart';

/// Target frame rate range supported by the camera hardware.
class FpsRange {
  /// Minimum frame rate in frames per second.
  final int min;

  /// Maximum frame rate in frames per second.
  final int max;

  /// Creates a frame rate range.
  const FpsRange({required this.min, required this.max});

  /// Creates an [FpsRange] from a serialized map.
  factory FpsRange.fromMap(Map<String, dynamic> map) {
    return FpsRange(
      min: (map['min'] as num).toInt(),
      max: (map['max'] as num).toInt(),
    );
  }

  /// Converts this [FpsRange] to a map.
  Map<String, dynamic> toMap() => {'min': min, 'max': max};

  @override
  String toString() => '$min-$max fps';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FpsRange &&
          runtimeType == other.runtimeType &&
          min == other.min &&
          max == other.max;

  @override
  int get hashCode => Object.hash(min, max);
}

/// Comprehensive hardware description and low-level capabilities of a camera sensor.
class NativeCameraDescription {
  /// Unique identifier of the camera on the device (e.g. '0', '1').
  final String id;

  /// Human readable display name (e.g. 'Back Camera (Wide)').
  final String name;

  /// Facing direction of the sensor.
  final CameraPosition position;

  /// Clockwise rotation in degrees needed to render the preview upright.
  final int sensorOrientation;

  /// Minimum ISO sensitivity supported by the sensor.
  final int minIso;

  /// Maximum ISO sensitivity supported by the sensor.
  final int maxIso;

  /// Minimum exposure duration (shutter speed) supported.
  final Duration minExposureDuration;

  /// Maximum exposure duration (shutter speed) supported.
  final Duration maxExposureDuration;

  /// Minimum focus distance (0.0 represents infinity).
  final double minFocusDistance;

  /// Maximum focus distance (macro focus closest point, e.g. 10.0 diopters on Android or 1.0 on iOS).
  final double maxFocusDistance;

  /// Minimum zoom factor (usually 1.0, or < 1.0 for ultra-wide).
  final double minZoom;

  /// Maximum digital/optical zoom factor supported.
  final double maxZoom;

  /// Minimum exposure compensation bias in EV (e.g. -2.0 or -3.0).
  final double minExposureBias;

  /// Maximum exposure compensation bias in EV (e.g. +2.0 or +3.0).
  final double maxExposureBias;

  /// Smallest step size for exposure compensation in EV (e.g. 0.333).
  final double exposureBiasStep;

  /// List of supported frame rate ranges.
  final List<FpsRange> supportedFpsRanges;

  /// Whether this camera sensor is paired with a physical flash.
  final bool supportsFlash;

  /// Whether this camera sensor supports continuous torch light.
  final bool supportsTorch;

  /// Whether the hardware supports manual focus distance overrides.
  final bool supportsManualFocus;

  /// Whether the hardware supports manual ISO and exposure time overrides.
  final bool supportsManualExposure;

  /// Creates a [NativeCameraDescription].
  const NativeCameraDescription({
    required this.id,
    required this.name,
    required this.position,
    required this.sensorOrientation,
    required this.minIso,
    required this.maxIso,
    required this.minExposureDuration,
    required this.maxExposureDuration,
    required this.minFocusDistance,
    required this.maxFocusDistance,
    required this.minZoom,
    required this.maxZoom,
    required this.minExposureBias,
    required this.maxExposureBias,
    required this.exposureBiasStep,
    required this.supportedFpsRanges,
    required this.supportsFlash,
    required this.supportsTorch,
    required this.supportsManualFocus,
    required this.supportsManualExposure,
  });

  /// Deserializes a [NativeCameraDescription] from a platform channel map.
  factory NativeCameraDescription.fromMap(Map<String, dynamic> map) {
    final positionStr = (map['position'] as String? ?? 'back').toLowerCase();
    final position = switch (positionStr) {
      'front' => CameraPosition.front,
      'external' => CameraPosition.external,
      _ => CameraPosition.back,
    };

    final rawFps = (map['supportedFpsRanges'] as List<dynamic>?) ?? [];
    final supportedFpsRanges = rawFps
        .map((f) => FpsRange.fromMap(Map<String, dynamic>.from(f as Map)))
        .toList();

    final minDurationMicroseconds =
        (map['minExposureDurationMicros'] as num?)?.toInt() ?? 100;
    final maxDurationMicroseconds =
        (map['maxExposureDurationMicros'] as num?)?.toInt() ?? 1000000;

    return NativeCameraDescription(
      id: map['id'] as String? ?? '0',
      name: map['name'] as String? ?? 'Camera ${map['id']}',
      position: position,
      sensorOrientation: (map['sensorOrientation'] as num?)?.toInt() ?? 90,
      minIso: (map['minIso'] as num?)?.toInt() ?? 50,
      maxIso: (map['maxIso'] as num?)?.toInt() ?? 3200,
      minExposureDuration: Duration(microseconds: minDurationMicroseconds),
      maxExposureDuration: Duration(microseconds: maxDurationMicroseconds),
      minFocusDistance: (map['minFocusDistance'] as num?)?.toDouble() ?? 0.0,
      maxFocusDistance: (map['maxFocusDistance'] as num?)?.toDouble() ?? 1.0,
      minZoom: (map['minZoom'] as num?)?.toDouble() ?? 1.0,
      maxZoom: (map['maxZoom'] as num?)?.toDouble() ?? 10.0,
      minExposureBias: (map['minExposureBias'] as num?)?.toDouble() ?? -2.0,
      maxExposureBias: (map['maxExposureBias'] as num?)?.toDouble() ?? 2.0,
      exposureBiasStep: (map['exposureBiasStep'] as num?)?.toDouble() ?? 0.1,
      supportedFpsRanges: supportedFpsRanges,
      supportsFlash: map['supportsFlash'] as bool? ?? false,
      supportsTorch: map['supportsTorch'] as bool? ?? false,
      supportsManualFocus: map['supportsManualFocus'] as bool? ?? true,
      supportsManualExposure: map['supportsManualExposure'] as bool? ?? true,
    );
  }

  /// Converts this description to a map for serialization.
  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'position': position.name,
        'sensorOrientation': sensorOrientation,
        'minIso': minIso,
        'maxIso': maxIso,
        'minExposureDurationMicros': minExposureDuration.inMicroseconds,
        'maxExposureDurationMicros': maxExposureDuration.inMicroseconds,
        'minFocusDistance': minFocusDistance,
        'maxFocusDistance': maxFocusDistance,
        'minZoom': minZoom,
        'maxZoom': maxZoom,
        'minExposureBias': minExposureBias,
        'maxExposureBias': maxExposureBias,
        'exposureBiasStep': exposureBiasStep,
        'supportedFpsRanges': supportedFpsRanges.map((r) => r.toMap()).toList(),
        'supportsFlash': supportsFlash,
        'supportsTorch': supportsTorch,
        'supportsManualFocus': supportsManualFocus,
        'supportsManualExposure': supportsManualExposure,
      };

  @override
  String toString() =>
      'NativeCameraDescription(id: $id, name: $name, position: $position, ISO: $minIso-$maxIso)';
}
