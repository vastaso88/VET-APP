import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart' as geolocator;

import '../../location/domain/coordinates.dart';
import '../../location/domain/geo_math.dart';
import '../domain/gps_fix.dart';
import '../domain/gps_quality.dart';
import '../domain/walk_session.dart';
import 'active_walk_recovery_store.dart';
import 'dog_walks_repository.dart';
import 'walk_foreground_service.dart';

/// Mirrors packages/core/domain/dog_walk/models.py:estimate_steps.
int estimateSteps(double distanceMeters, {double strideMeters = 0.75}) {
  if (distanceMeters <= 0) {
    return 0;
  }
  return (distanceMeters / strideMeters).round();
}

/// Owns the start/stop/pause lifecycle of one dog walk. Lives for the app's
/// whole lifetime as [instance] - previously a page-scoped object disposed
/// (and so silently stopped tracking) whenever the owner navigated away
/// from ActiveWalkPage mid-walk (owner report, 2026-09-29). Tests construct
/// their own throwaway instance and feed it a synthetic [GpsFix] stream
/// instead of touching `geolocator`.
class ActiveWalkController extends ChangeNotifier {
  ActiveWalkController({
    required DogWalksRepository repository,
    ActiveWalkRecoveryStore recoveryStore = const ActiveWalkRecoveryStore(),
    WalkForegroundService foregroundService = const NoopWalkForegroundService(),
  })  : _repository = repository,
        _recoveryStore = recoveryStore,
        _foregroundService = foregroundService;

  static final ActiveWalkController instance = ActiveWalkController(
    repository: DogWalksRepository(),
    foregroundService: WalkForegroundService.forPlatform(),
  );

  final DogWalksRepository _repository;
  final ActiveWalkRecoveryStore _recoveryStore;

  /// The walk's own ongoing notification + Android foreground service
  /// (WalkTrackingService.kt) - what keeps GPS alive in the background.
  final WalkForegroundService _foregroundService;
  StreamSubscription<GpsFix>? _subscription;

  /// True when the walk's own notification couldn't be started and the
  /// device stream carries geolocator's foreground notification instead.
  /// Only then is the stream restarted on pause/resume, purely to swap that
  /// notification's text (the plugin can't edit it in place). With the
  /// walk's own notification, pausing just re-posts it - restarting GPS
  /// from the background (a pause from the widget) is refused by Android
  /// 12+ and used to silently stop tracking (2026-10-07).
  bool _usingFallbackNotification = false;

  /// Set on [resume] so the very next accepted fix starts a new route
  /// segment (walk_route_segments.dart) instead of being compared/joined
  /// to the point recorded right before the pause.
  bool _pendingSegmentBreak = false;

  WalkSession? _walk;
  WalkSession? get walk => _walk;

  bool get isActive => _walk?.status == WalkStatus.inProgress;

  // --- Read-only surface for other UI that isn't the walk pages themselves
  // (the home-screen widget, the shell banner) - listen via this
  // ChangeNotifier (AnimatedBuilder/addListener), there is no separate
  // ValueListenable. Never call into the widget from here - this class only
  // exposes state, it doesn't know the widget exists (2026-09-30).

  /// Whether a walk is currently tracking or paused (i.e. [walk] is
  /// in-progress, in either sense).
  bool get hasActiveWalk => isActive;

  /// The pet the active walk belongs to, or null if none. This class has no
  /// notion of a pet's *name* - resolve that from PetDemoStore given this
  /// id, same as home_shell_page.dart's banner and walk_home_widget.dart
  /// already do.
  String? get activePetId => _walk?.petId;

  double get activeDistanceMeters => _walk?.distanceMeters ?? 0;

  /// "Moving time" so far, excluding any pause (walk_session.dart's
  /// walkActiveDurationSeconds) - 0 when there's no active walk.
  int get activeSeconds => _walk == null ? 0 : walkActiveDurationSeconds(_walk!);

  bool get isPaused => _walk?.isPaused ?? false;

  double? _headingDegrees;
  double? get headingDegrees => _headingDegrees;

  bool _awaitingAccurateStart = false;

  /// True right after [start] while waiting for a fix accurate enough to
  /// record the route's first point (gps_quality.dart) - lets the page show
  /// a short "in attesa di un segnale GPS preciso" instead of an empty map.
  bool get isAwaitingAccurateFix => _awaitingAccurateStart;

  Future<void> start({
    required String ownerId,
    required String petId,
    Stream<GpsFix>? positionStream,
  }) async {
    final walk = WalkSession(
      id: 'walk-${DateTime.now().microsecondsSinceEpoch}',
      ownerId: ownerId,
      petId: petId,
      startedAt: DateTime.now(),
    );
    _walk = walk;
    _awaitingAccurateStart = true;
    notifyListeners();
    final hasOwnNotification = await _foregroundService.start(walk);
    _usingFallbackNotification = positionStream == null && !hasOwnNotification;
    await _repository.saveWalk(walk);
    await _recoveryStore.save(walk);

    await _attachStream(
      positionStream ?? _defaultPositionStream(paused: false),
    );
  }

  /// Reattaches a live stream to a walk recovered from disk after the app
  /// process was killed mid-walk (ActiveWalkRecoveryStore) - the
  /// accumulated route/distance carries over, only the GPS subscription is
  /// new. Skips the "wait for an accurate first fix" gate (there's already
  /// at least one accepted point), but still starts a new route segment,
  /// same as any other resume - the app being closed and reopened is itself
  /// a gap worth not drawing a line across.
  Future<void> recoverInterrupted(
    WalkSession recoveredWalk, {
    Stream<GpsFix>? positionStream,
  }) async {
    _walk = recoveredWalk;
    _awaitingAccurateStart = false;
    _pendingSegmentBreak = recoveredWalk.route.isNotEmpty;
    notifyListeners();

    final hasOwnNotification = await _foregroundService.start(recoveredWalk);
    _usingFallbackNotification = positionStream == null && !hasOwnNotification;
    await _attachStream(
      positionStream ?? _defaultPositionStream(paused: recoveredWalk.isPaused),
    );
  }

  /// Freezes the live timer and stops recording route points (owner
  /// request, 2026-09-30) - GPS fixes keep arriving but _onFix ignores them
  /// until [resume]. The walk notification switches to its "in pausa" text.
  Future<void> pause() async {
    final current = _walk;
    if (current == null ||
        current.status != WalkStatus.inProgress ||
        current.isPaused) {
      return;
    }

    _walk = current.copyWith(isPaused: true, pausedAt: DateTime.now());
    notifyListeners();
    await _repository.saveWalk(_walk!);
    await _recoveryStore.save(_walk!);

    if (_usingFallbackNotification) {
      await _attachStream(_defaultPositionStream(paused: true));
    } else {
      await _foregroundService.update(_walk!);
    }
  }

  /// Undoes [pause]: folds the just-finished pause interval into
  /// [WalkSession.pausedSeconds] and marks the next accepted fix as the
  /// start of a new route segment, so the map doesn't draw a line across
  /// whatever ground was covered while paused.
  Future<void> resume() async {
    final current = _walk;
    if (current == null ||
        current.status != WalkStatus.inProgress ||
        !current.isPaused) {
      return;
    }

    final now = DateTime.now();
    final justPaused =
        current.pausedAt == null ? 0 : now.difference(current.pausedAt!).inSeconds;
    // copyWith can't clear pausedAt back to null (its `??` pattern only
    // ever keeps-or-replaces with a non-null value), so this one field is
    // constructed directly rather than stretching that helper for one case.
    _walk = WalkSession(
      id: current.id,
      ownerId: current.ownerId,
      petId: current.petId,
      status: current.status,
      startedAt: current.startedAt,
      endedAt: current.endedAt,
      distanceMeters: current.distanceMeters,
      durationSeconds: current.durationSeconds,
      stepCountEstimate: current.stepCountEstimate,
      route: current.route,
      isFavorite: current.isFavorite,
      isPaused: false,
      pausedAt: null,
      pausedSeconds: current.pausedSeconds + justPaused,
    );
    _pendingSegmentBreak = true;
    notifyListeners();
    await _repository.saveWalk(_walk!);
    await _recoveryStore.save(_walk!);

    if (_usingFallbackNotification) {
      await _attachStream(_defaultPositionStream(paused: false));
    } else {
      await _foregroundService.update(_walk!);
    }
  }

  Future<void> _attachStream(Stream<GpsFix> stream) async {
    await _subscription?.cancel();
    _subscription = stream.listen(_onFix);
  }

  Stream<GpsFix> _defaultPositionStream({required bool paused}) {
    return geolocator.Geolocator.getPositionStream(
      locationSettings: _androidAwareSettings(paused: paused),
    ).map(_toGpsFix);
  }

  /// On Android, tracking survives the owner switching to another app
  /// mid-walk (owner report, 2026-09-29) because a foreground service with
  /// a persistent notification runs alongside: normally the walk's own
  /// (WalkTrackingService.kt via [_foregroundService]), otherwise - only if
  /// that one couldn't start - geolocator's built-in one configured here.
  /// Either needs only the foreground location permission the app already
  /// requests - not ACCESS_BACKGROUND_LOCATION ("Allow all the time"),
  /// which docs/compliance/05_permessi_dispositivo_os.md explicitly defers.
  /// bestForNavigation + a short interval trade extra battery for the
  /// tighter accuracy the owner asked for (2026-09-29). Other platforms keep
  /// plain settings, web ignores AndroidSettings entirely.
  geolocator.LocationSettings _androidAwareSettings({required bool paused}) {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return geolocator.AndroidSettings(
        accuracy: geolocator.LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
        intervalDuration: const Duration(seconds: 3),
        foregroundNotificationConfig: !_usingFallbackNotification
            ? null
            : geolocator.ForegroundNotificationConfig(
                notificationTitle:
                    paused ? 'Passeggiata in pausa' : 'Passeggiata in corso',
                notificationText: paused
                    ? 'Il tracciamento è in pausa. Riprendi dall\'app quando vuoi.'
                    : 'VetApp sta tracciando il percorso della passeggiata.',
                notificationChannelName: 'Tracciamento passeggiata',
                setOngoing: true,
              ),
      );
    }
    return const geolocator.LocationSettings(
      accuracy: geolocator.LocationAccuracy.best,
      distanceFilter: 5,
    );
  }

  GpsFix _toGpsFix(geolocator.Position position) {
    return GpsFix(
      coordinates: Coordinates(
          latitude: position.latitude, longitude: position.longitude),
      recordedAt: position.timestamp,
      accuracyMeters: position.accuracy,
      speedMetersPerSecond: position.speed,
      headingDegrees: position.heading,
    );
  }

  void _onFix(GpsFix fix) {
    final current = _walk;
    if (current == null || current.status != WalkStatus.inProgress) {
      return;
    }

    final heading = fix.headingDegrees;
    if (heading != null && !heading.isNaN && heading >= 0 && heading <= 360) {
      _headingDegrees = heading;
    }

    if (current.isPaused) {
      notifyListeners();
      return;
    }

    if (_awaitingAccurateStart) {
      if (!isFixAccurateEnoughToStart(fix)) {
        notifyListeners();
        return;
      }
      _awaitingAccurateStart = false;
    }

    final startingNewSegment = _pendingSegmentBreak;
    // A segment start is compared against nothing, same as the walk's very
    // first point - the gap it may be crossing (however long the pause
    // lasted) isn't a GPS glitch, so it shouldn't fail the speed check or
    // get smoothed toward the pre-pause point, and shouldn't add distance.
    final lastPoint =
        startingNewSegment ? null : (current.route.isEmpty ? null : current.route.last);

    final rawPoint = filterAndSmoothFix(fix, lastPoint);
    if (rawPoint == null) {
      notifyListeners();
      return;
    }
    final point = startingNewSegment
        ? RoutePoint(
            coordinates: rawPoint.coordinates,
            recordedAt: rawPoint.recordedAt,
            accuracyMeters: rawPoint.accuracyMeters,
            startsNewSegment: true,
          )
        : rawPoint;
    if (startingNewSegment) {
      _pendingSegmentBreak = false;
    }

    final addedDistance = lastPoint == null
        ? 0.0
        : haversineMeters(lastPoint.coordinates, point.coordinates);
    final updated = current.copyWith(
      route: [...current.route, point],
      distanceMeters: current.distanceMeters + addedDistance,
    );
    _walk = updated;
    notifyListeners();
    unawaited(_repository.saveWalk(updated));
    unawaited(_recoveryStore.save(updated));
    unawaited(_foregroundService.update(updated));
  }

  Future<void> stop() async {
    final current = _walk;
    if (current == null || current.status != WalkStatus.inProgress) {
      return;
    }

    await _subscription?.cancel();
    _subscription = null;
    await _foregroundService.stop();
    _usingFallbackNotification = false;

    final endedAt = DateTime.now();
    final updated = current.copyWith(
      status: WalkStatus.completed,
      endedAt: endedAt,
      durationSeconds: walkActiveDurationSeconds(current, now: endedAt),
      stepCountEstimate: estimateSteps(current.distanceMeters),
      isPaused: false,
    );
    _walk = updated;
    _headingDegrees = null;
    notifyListeners();
    await _repository.saveWalk(updated);
    await _recoveryStore.clear();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    unawaited(_foregroundService.stop());
    super.dispose();
  }
}
