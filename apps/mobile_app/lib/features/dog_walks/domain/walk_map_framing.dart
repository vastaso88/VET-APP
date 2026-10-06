import 'dart:math' as math;

import 'walk_session.dart';

/// The rectangle a walk's thumbnail should show: the route's own bounds, grown
/// to at least [minSpanMeters] on each side so a very short walk does not
/// collapse into a single dot under the start/finish markers (owner report,
/// 2026-10-06: thumbnails showed only a flag).
class WalkMapFrame {
  const WalkMapFrame({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });

  final double south;
  final double west;
  final double north;
  final double east;

  double get centerLatitude => (south + north) / 2;
  double get centerLongitude => (west + east) / 2;

  @override
  bool operator ==(Object other) =>
      other is WalkMapFrame &&
      other.south == south &&
      other.west == west &&
      other.north == north &&
      other.east == east;

  @override
  int get hashCode => Object.hash(south, west, north, east);

  @override
  String toString() => 'WalkMapFrame($south, $west, $north, $east)';
}

const _metersPerDegreeLatitude = 111320.0;

/// Null when the route cannot be drawn as a path (fewer than two points).
WalkMapFrame? walkMapFrame(List<RoutePoint> route, {double minSpanMeters = 250}) {
  if (route.length < 2) return null;

  var south = double.infinity;
  var north = -double.infinity;
  var west = double.infinity;
  var east = -double.infinity;
  for (final point in route) {
    final latitude = point.coordinates.latitude;
    final longitude = point.coordinates.longitude;
    south = math.min(south, latitude);
    north = math.max(north, latitude);
    west = math.min(west, longitude);
    east = math.max(east, longitude);
  }

  final centerLatitude = (south + north) / 2;
  final centerLongitude = (west + east) / 2;
  final minLatitudeSpan = minSpanMeters / _metersPerDegreeLatitude;
  final cosine = math.max(0.1, math.cos(centerLatitude * math.pi / 180));
  final minLongitudeSpan = minSpanMeters / (_metersPerDegreeLatitude * cosine);

  final latitudeSpan = math.max(north - south, minLatitudeSpan);
  final longitudeSpan = math.max(east - west, minLongitudeSpan);

  return WalkMapFrame(
    south: centerLatitude - latitudeSpan / 2,
    north: centerLatitude + latitudeSpan / 2,
    west: centerLongitude - longitudeSpan / 2,
    east: centerLongitude + longitudeSpan / 2,
  );
}
