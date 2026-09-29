import '../../location/domain/coordinates.dart';
import '../../location/domain/geo_math.dart';
import 'gps_fix.dart';
import 'walk_session.dart';

/// GPS-quality gates for recording a walk's route (owner report, 2026-09-29:
/// recorded routes were "molto approssimative"). These are tuned thresholds,
/// not a full sensor-fusion solution - see the doc comments on each
/// constant for what they do and don't fix.

/// A fix needs at least this good an accuracy before the walk starts
/// recording its very first point - a cold GPS fix in the first second or
/// two is often wildly off, and starting the route there draws a spurious
/// jump before the real path even begins.
const double walkMinStartAccuracyMeters = 25;

/// Any fix worse than this (in any direction, not just at the start) is
/// dropped outright rather than recorded - it wouldn't just be slightly
/// off, it would draw a visible zig-zag or teleport on the map.
const double walkMaxAcceptableAccuracyMeters = 50;

/// Above this implied speed between two consecutive accepted points, the
/// jump is treated as a GPS glitch rather than the owner actually moving
/// that fast - about 29 km/h, generous enough to cover a jog without
/// rejecting real movement, but well past normal walking pace.
const double walkMaxPlausibleSpeedMetersPerSecond = 8;

/// How much a smoothed point is pulled toward the previous one before
/// being accepted, damping small GPS jitter so the drawn route doesn't
/// zig-zag between fixes that are each individually "accurate enough" but
/// still noisy relative to each other. 1.0 would mean no smoothing at all;
/// this is a fixed weight, not an adaptive filter (a Kalman filter would
/// do better, in particular the first-few-points snap the smoothed point
/// only partway to the raw fix, so very early-route smoothing is weaker).
const double _smoothingWeight = 0.65;

bool isFixAccurateEnoughToStart(GpsFix fix) {
  final accuracy = fix.accuracyMeters;
  return accuracy != null && accuracy <= walkMinStartAccuracyMeters;
}

/// Returns null when [fix] should be dropped (bad accuracy, or an
/// impossible jump from [lastAccepted]); otherwise the point to actually
/// record, smoothed toward [lastAccepted] when there is one.
RoutePoint? filterAndSmoothFix(GpsFix fix, RoutePoint? lastAccepted) {
  final accuracy = fix.accuracyMeters;
  if (accuracy != null && accuracy > walkMaxAcceptableAccuracyMeters) {
    return null;
  }

  if (lastAccepted == null) {
    return RoutePoint(
      coordinates: fix.coordinates,
      recordedAt: fix.recordedAt,
      accuracyMeters: fix.accuracyMeters,
    );
  }

  final elapsedSeconds =
      fix.recordedAt.difference(lastAccepted.recordedAt).inMilliseconds / 1000;
  if (elapsedSeconds > 0) {
    final rawDistance =
        haversineMeters(lastAccepted.coordinates, fix.coordinates);
    final impliedSpeed = rawDistance / elapsedSeconds;
    if (impliedSpeed > walkMaxPlausibleSpeedMetersPerSecond) {
      return null;
    }
  }

  final smoothed = Coordinates(
    latitude: lastAccepted.coordinates.latitude +
        (fix.coordinates.latitude - lastAccepted.coordinates.latitude) *
            _smoothingWeight,
    longitude: lastAccepted.coordinates.longitude +
        (fix.coordinates.longitude - lastAccepted.coordinates.longitude) *
            _smoothingWeight,
  );
  return RoutePoint(
    coordinates: smoothed,
    recordedAt: fix.recordedAt,
    accuracyMeters: fix.accuracyMeters,
  );
}
