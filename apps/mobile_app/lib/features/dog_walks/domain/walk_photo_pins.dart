import '../../location/domain/coordinates.dart';
import 'photo_walk_match.dart';
import 'walk_session.dart';

/// Where on a walk's route a photo was taken (owner request, 2026-10-12).
///
/// A photo's own GPS is stripped for privacy, so the place is rebuilt from the
/// route: the position the walk had at the instant the photo was taken.
class WalkPhotoPin {
  const WalkPhotoPin({required this.photoId, required this.takenAt, required this.at});

  final String photoId;
  final DateTime takenAt;
  final Coordinates at;
}

/// Where the route was at [moment], or null for an empty route.
///
/// Between two consecutive recorded points the position is interpolated by
/// time. Across a pause (the next point starts a new segment) nobody moved, so
/// the answer is the last point before the pause instead of a point on the
/// straight line over ground that was never walked. Before the first point
/// (the walk had started but not yet found a GPS fix) it is the first point;
/// after the last, the last. Points are expected oldest first, as recorded.
Coordinates? routePositionAt(List<RoutePoint> route, DateTime moment) {
  if (route.isEmpty) return null;
  final target = moment.millisecondsSinceEpoch;
  if (target <= route.first.recordedAt.millisecondsSinceEpoch) {
    return route.first.coordinates;
  }
  if (target >= route.last.recordedAt.millisecondsSinceEpoch) {
    return route.last.coordinates;
  }

  for (var index = 0; index < route.length - 1; index++) {
    final before = route[index];
    final after = route[index + 1];
    final start = before.recordedAt.millisecondsSinceEpoch;
    final end = after.recordedAt.millisecondsSinceEpoch;
    if (target < start || target > end) continue;
    if (after.startsNewSegment || end == start) return before.coordinates;

    final fraction = (target - start) / (end - start);
    return Coordinates(
      latitude: before.coordinates.latitude +
          (after.coordinates.latitude - before.coordinates.latitude) * fraction,
      longitude: before.coordinates.longitude +
          (after.coordinates.longitude - before.coordinates.longitude) * fraction,
    );
  }
  return route.last.coordinates;
}

/// One pin per photo taken during [walk], oldest first. Photos without a
/// shooting time, taken outside the walk (the very same window the gallery's
/// "Passeggiata del ..." caption uses, see [walkForPhoto]) or on a walk with
/// no recorded route produce nothing.
List<WalkPhotoPin> walkPhotoPins(
  WalkSession walk,
  Iterable<({String id, DateTime? takenAt})> photos, {
  DateTime? now,
}) {
  if (walk.route.isEmpty) return const [];
  final pins = <WalkPhotoPin>[];
  for (final photo in photos) {
    final takenAt = photo.takenAt;
    if (takenAt == null) continue;
    if (walkForPhoto(takenAt, [walk], now: now)?.id != walk.id) continue;
    final at = routePositionAt(walk.route, takenAt);
    if (at == null) continue;
    pins.add(WalkPhotoPin(photoId: photo.id, takenAt: takenAt, at: at));
  }
  pins.sort((a, b) => a.takenAt.compareTo(b.takenAt));
  return pins;
}
