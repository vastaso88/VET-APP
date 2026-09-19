import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../location/domain/coordinates.dart';
import '../domain/walk_session.dart';
import 'dog_walks_repository.dart';

const double _earthRadiusMeters = 6371008.8;

/// Mirrors packages/core/domain/geo/models.py:haversine_distance_km so the
/// notion of "distance walked" matches between client and backend.
double _haversineMeters(Coordinates a, Coordinates b) {
  final lat1 = a.latitude * math.pi / 180;
  final lat2 = b.latitude * math.pi / 180;
  final deltaLat = (b.latitude - a.latitude) * math.pi / 180;
  final deltaLon = (b.longitude - a.longitude) * math.pi / 180;

  final h = math.pow(math.sin(deltaLat / 2), 2) +
      math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(deltaLon / 2), 2);
  return 2 * _earthRadiusMeters * math.asin(math.sqrt(h));
}

/// Mirrors packages/core/domain/dog_walk/models.py:estimate_steps.
int estimateSteps(double distanceMeters, {double strideMeters = 0.75}) {
  if (distanceMeters <= 0) {
    return 0;
  }
  return (distanceMeters / strideMeters).round();
}

/// Owns the start/stop lifecycle of one dog walk by consuming an injected
/// position stream, so tests can feed synthetic coordinates and assert on
/// accumulated distance/route length without a real `geolocator` call.
class ActiveWalkController extends ChangeNotifier {
  ActiveWalkController({required DogWalksRepository repository}) : _repository = repository;

  final DogWalksRepository _repository;
  StreamSubscription<Coordinates>? _subscription;

  WalkSession? _walk;
  WalkSession? get walk => _walk;

  bool get isActive => _walk?.status == WalkStatus.inProgress;

  Future<void> start({
    required String ownerId,
    required String petId,
    required Stream<Coordinates> positionStream,
  }) async {
    final walk = WalkSession(
      id: 'walk-${DateTime.now().microsecondsSinceEpoch}',
      ownerId: ownerId,
      petId: petId,
      startedAt: DateTime.now(),
    );
    _walk = walk;
    notifyListeners();
    await _repository.saveWalk(walk);

    await _subscription?.cancel();
    _subscription = positionStream.listen(_onPosition);
  }

  void _onPosition(Coordinates coordinates) {
    final current = _walk;
    if (current == null || current.status != WalkStatus.inProgress) {
      return;
    }

    final point = RoutePoint(coordinates: coordinates, recordedAt: DateTime.now());
    final addedDistance =
        current.route.isEmpty ? 0.0 : _haversineMeters(current.route.last.coordinates, coordinates);

    final updated = current.copyWith(
      route: [...current.route, point],
      distanceMeters: current.distanceMeters + addedDistance,
    );
    _walk = updated;
    notifyListeners();
    unawaited(_repository.saveWalk(updated));
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
    notifyListeners();
    await _repository.saveWalk(updated);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
