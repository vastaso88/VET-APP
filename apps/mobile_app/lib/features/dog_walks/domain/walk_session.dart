import '../../location/domain/coordinates.dart';

enum WalkStatus { inProgress, completed, discarded }

class RoutePoint {
  const RoutePoint({
    required this.coordinates,
    required this.recordedAt,
    this.accuracyMeters,
    this.startsNewSegment = false,
  });

  final Coordinates coordinates;
  final DateTime recordedAt;
  final double? accuracyMeters;

  /// True for the first point recorded after a Pausa/Riavvia (owner request,
  /// 2026-09-30): the route stayed one flat list rather than a list of
  /// segments, so this is what tells the map renderer where to start a new
  /// polyline instead of drawing a line across whatever ground was covered
  /// while paused.
  final bool startsNewSegment;
}

class WalkSession {
  const WalkSession({
    required this.id,
    required this.ownerId,
    required this.petId,
    this.status = WalkStatus.inProgress,
    required this.startedAt,
    this.endedAt,
    this.distanceMeters = 0,
    this.durationSeconds,
    this.stepCountEstimate,
    this.route = const [],
    this.isFavorite = false,
    this.isPaused = false,
    this.pausedAt,
    this.pausedSeconds = 0,
  });

  final String id;
  final String ownerId;
  final String petId;
  final WalkStatus status;
  final DateTime startedAt;
  final DateTime? endedAt;
  final double distanceMeters;
  final int? durationSeconds;
  final int? stepCountEstimate;
  final List<RoutePoint> route;

  /// Starred by the owner at the end of a walk (max 5 per pet - see
  /// dog_walks_repository.dart's retention logic). Independent of whether
  /// this is also the all-time longest walk.
  final bool isFavorite;

  /// Only meaningful while [status] is inProgress - GPS fixes are ignored
  /// (gps_quality.dart's filters never run) and the live timer freezes
  /// while true (owner request, 2026-09-30).
  final bool isPaused;

  /// When the current pause began, or null if not paused right now. Kept
  /// separate from [pausedSeconds] (completed pause intervals) so
  /// walkActiveDurationSeconds can add "how long the current pause has
  /// lasted so far" without mutating anything on every tick.
  final DateTime? pausedAt;

  /// Total seconds spent paused across every *completed* pause/resume
  /// cycle so far - does not include however long [pausedAt] has been
  /// running, if still paused.
  final int pausedSeconds;

  WalkSession copyWith({
    WalkStatus? status,
    DateTime? endedAt,
    double? distanceMeters,
    int? durationSeconds,
    int? stepCountEstimate,
    List<RoutePoint>? route,
    bool? isFavorite,
    bool? isPaused,
    DateTime? pausedAt,
    int? pausedSeconds,
  }) {
    return WalkSession(
      id: id,
      ownerId: ownerId,
      petId: petId,
      status: status ?? this.status,
      startedAt: startedAt,
      endedAt: endedAt ?? this.endedAt,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      stepCountEstimate: stepCountEstimate ?? this.stepCountEstimate,
      route: route ?? this.route,
      isFavorite: isFavorite ?? this.isFavorite,
      isPaused: isPaused ?? this.isPaused,
      pausedAt: pausedAt ?? this.pausedAt,
      pausedSeconds: pausedSeconds ?? this.pausedSeconds,
    );
  }
}

/// "Moving time": wall-clock time since the walk started, minus every pause
/// interval (including the one in progress right now, if still paused).
/// Used both by the live in-app timer and by the final `durationSeconds`
/// saved when the walk ends, so a long rest stop doesn't inflate either one.
int walkActiveDurationSeconds(WalkSession walk, {DateTime? now}) {
  final reference = walk.endedAt ?? now ?? DateTime.now();
  final wallClockSeconds = reference.difference(walk.startedAt).inSeconds;

  var pausedTotal = walk.pausedSeconds;
  if (walk.isPaused && walk.pausedAt != null) {
    pausedTotal += reference.difference(walk.pausedAt!).inSeconds;
  }

  final active = wallClockSeconds - pausedTotal;
  return active < 0 ? 0 : active;
}
