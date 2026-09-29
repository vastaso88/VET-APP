import 'walk_session.dart';

/// Splits a walk's flat `route` into the pieces that should each be drawn
/// as their own polyline - a new piece starts at every point with
/// `startsNewSegment` set (Pausa/Riavvia, walk_session.dart), so resuming
/// after a pause never draws a line across whatever ground was covered
/// while paused.
List<List<RoutePoint>> splitRouteIntoSegments(List<RoutePoint> route) {
  if (route.isEmpty) return const [];

  final segments = <List<RoutePoint>>[];
  var current = <RoutePoint>[route.first];
  for (final point in route.skip(1)) {
    if (point.startsNewSegment) {
      segments.add(current);
      current = [point];
    } else {
      current.add(point);
    }
  }
  segments.add(current);
  return segments;
}
