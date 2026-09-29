import '../../location/domain/coordinates.dart';
import 'walk_route_segments.dart';
import 'walk_session.dart';

/// Where to draw the start/pause/finish markers for a walk's map (owner
/// request, 2026-09-30), computed from the same segments the polyline
/// itself is split on (walk_route_segments.dart) so the two always agree.
/// Pure/coordinate-only so it's usable from the live tracker, the history
/// thumbnail, and the full-screen detail page without depending on
/// flutter_map - each of those turns this into actual `Marker`s
/// (walk_route_markers_layer.dart).
class WalkRouteMarkers {
  const WalkRouteMarkers({this.start, this.pausePoints = const [], this.finish});

  final Coordinates? start;

  /// One per pause, at the last point recorded before that pause began -
  /// "here's where you stopped", not where you resumed.
  final List<Coordinates> pausePoints;

  /// Null for a walk still in progress (there's no finish yet) or an empty
  /// route - only set for a completed walk with at least one point.
  final Coordinates? finish;
}

WalkRouteMarkers computeWalkRouteMarkers(List<RoutePoint> route, {required bool isFinished}) {
  final segments = splitRouteIntoSegments(route);
  if (segments.isEmpty) {
    return const WalkRouteMarkers();
  }

  final pausePoints = [
    for (var i = 0; i < segments.length - 1; i++) segments[i].last.coordinates,
  ];
  final lastSegment = segments.last;

  return WalkRouteMarkers(
    start: segments.first.first.coordinates,
    pausePoints: pausePoints,
    finish: isFinished ? lastSegment.last.coordinates : null,
  );
}
