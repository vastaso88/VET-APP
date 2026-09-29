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

/// Mirrors packages/core/domain/dog_walk/models.py:estimate_steps.
int estimateSteps(double distanceMeters, {double strideMeters = 0.75}) {
  if (distanceMeters <= 0) {
    return 0;
  }
  return (distanceMeters / strideMeters).round();
}

/// Owns the start/stop lifecycle of one dog walk. Lives for the app's whole
/// lifetime as [instance] - previously a page-scoped object disposed (and
/// so silently stopped tracking) whenever the owner navigated away from
/// ActiveWalkPage mid-walk (owner report, 2026-09-29). Tests construct
/// their own throwaway instance and feed it a synthetic [GpsFix] stream
/// instead of touching `geolocator`.
class ActiveWalkController extends ChangeNotifier {
  ActiveWalkController({
    required DogWalksRepository repository,
    ActiveWalkRecoveryStore recoveryStore = const ActiveWalkRecoveryStore(),
  })  : _repository = repository,
        _recoveryStore = recoveryStore;

  static final ActiveWalkController instance =
      ActiveWalkController(repository: DogWalksRepository());

  final DogWalksRepository _repository;
  final ActiveWalkRecoveryStore _recoveryStore;
  StreamSubscription<GpsFix>? _subscription;

  WalkSession? _walk;
  WalkSession? get walk => _walk;

  bool get isActive => _walk?.status == WalkStatus.inProgress;

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
    await _repository.saveWalk(walk);
    await _recoveryStore.save(walk);

    await _attachStream(positionStream ?? _defaultPositionStream());
  }

  /// Reattaches a live stream to a walk recovered from disk after the app
  /// process was killed mid-walk (ActiveWalkRecoveryStore) - the
  /// accumulated route/distance carries over, only the GPS subscription is
  /// new, and it's already past the "wait for an accurate first fix" gate.
  Future<void> resume(WalkSession recoveredWalk,
      {Stream<GpsFix>? positionStream}) async {
    _walk = recoveredWalk;
    _awaitingAccurateStart = false;
    notifyListeners();
    await _attachStream(positionStream ?? _defaultPositionStream());
  }

  Future<void> _attachStream(Stream<GpsFix> stream) async {
    await _subscription?.cancel();
    _subscription = stream.listen(_onFix);
  }

  Stream<GpsFix> _defaultPositionStream() {
    return geolocator.Geolocator.getPositionStream(
            locationSettings: _androidAwareSettings())
        .map(_toGpsFix);
  }

  /// On Android, runs GPS updates as a foreground service with a persistent
  /// notification so tracking survives the owner switching to another app
  /// mid-walk (owner report, 2026-09-29). This only needs the foreground
  /// location permission the app already requests - it's not
  /// ACCESS_BACKGROUND_LOCATION ("Allow all the time"), which
  /// docs/compliance/05_permessi_dispositivo_os.md explicitly defers.
  /// bestForNavigation + a short interval trade extra battery for the
  /// tighter accuracy the owner asked for (2026-09-29); other platforms
  /// keep plain settings, web ignores AndroidSettings entirely.
  geolocator.LocationSettings _androidAwareSettings() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return geolocator.AndroidSettings(
        accuracy: geolocator.LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
        intervalDuration: const Duration(seconds: 3),
        foregroundNotificationConfig:
            const geolocator.ForegroundNotificationConfig(
          notificationTitle: 'Passeggiata in corso',
          notificationText:
              'VetApp sta tracciando il percorso della passeggiata.',
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

    if (_awaitingAccurateStart) {
      if (!isFixAccurateEnoughToStart(fix)) {
        notifyListeners();
        return;
      }
      _awaitingAccurateStart = false;
    }

    final lastPoint = current.route.isEmpty ? null : current.route.last;
    final point = filterAndSmoothFix(fix, lastPoint);
    if (point == null) {
      notifyListeners();
      return;
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
  }

  Future<void> stop() async {
    final current = _walk;
    if (current == null || current.status != WalkStatus.inProgress) {
      return;
    }

    await _subscription?.cancel();
    _subscription = null;

    final endedAt = DateTime.now();
    final updated = current.copyWith(
      status: WalkStatus.completed,
      endedAt: endedAt,
      durationSeconds: endedAt.difference(current.startedAt).inSeconds,
      stepCountEstimate: estimateSteps(current.distanceMeters),
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
    super.dispose();
  }
}
