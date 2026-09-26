import '../../location/domain/coordinates.dart';

enum WalkStatus { inProgress, completed, discarded }

class RoutePoint {
  const RoutePoint({required this.coordinates, required this.recordedAt, this.accuracyMeters});

  final Coordinates coordinates;
  final DateTime recordedAt;
  final double? accuracyMeters;
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

  WalkSession copyWith({
    WalkStatus? status,
    DateTime? endedAt,
    double? distanceMeters,
    int? durationSeconds,
    int? stepCountEstimate,
    List<RoutePoint>? route,
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
    );
  }
}
