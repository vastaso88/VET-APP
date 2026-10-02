import '../../location/domain/coordinates.dart';

/// One GPS reading as fed into [ActiveWalkController] - decoupled from
/// `geolocator.Position` so tests can build one without that type's dozen
/// required fields, and so the filtering/smoothing logic in gps_quality.dart
/// isn't tied to any one location plugin.
class GpsFix {
  const GpsFix({
    required this.coordinates,
    required this.recordedAt,
    this.accuracyMeters,
    this.speedMetersPerSecond,
    this.headingDegrees,
  });

  final Coordinates coordinates;
  final DateTime recordedAt;
  final double? accuracyMeters;
  final double? speedMetersPerSecond;

  /// Course-over-ground, not a magnetometer compass - only meaningful while
  /// actually moving. Null when the platform doesn't report it.
  final double? headingDegrees;
}
