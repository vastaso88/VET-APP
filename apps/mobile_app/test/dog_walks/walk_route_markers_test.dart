import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/dog_walks/domain/walk_route_markers.dart';
import 'package:vet_app_mobile/features/dog_walks/domain/walk_session.dart';
import 'package:vet_app_mobile/features/location/domain/coordinates.dart';

RoutePoint _point(double lat, {bool startsNewSegment = false}) {
  return RoutePoint(
    coordinates: Coordinates(latitude: lat, longitude: 9.19),
    recordedAt: DateTime(2026, 1, 1),
    startsNewSegment: startsNewSegment,
  );
}

void main() {
  test('an empty route has no markers at all', () {
    final markers = computeWalkRouteMarkers(const [], isFinished: true);

    expect(markers.start, isNull);
    expect(markers.pausePoints, isEmpty);
    expect(markers.finish, isNull);
  });

  test('a single-segment route has a start and a finish, no pause markers', () {
    final route = [_point(45.1), _point(45.2), _point(45.3)];

    final markers = computeWalkRouteMarkers(route, isFinished: true);

    expect(markers.start, route.first.coordinates);
    expect(markers.pausePoints, isEmpty);
    expect(markers.finish, route.last.coordinates);
  });

  test('finish is null while the walk is still in progress', () {
    final route = [_point(45.1), _point(45.2)];

    final markers = computeWalkRouteMarkers(route, isFinished: false);

    expect(markers.finish, isNull);
    expect(markers.start, route.first.coordinates);
  });

  test('one pause marker per break, at the point before the pause', () {
    final beforePause = _point(45.2);
    final route = [
      _point(45.1),
      beforePause,
      _point(45.3, startsNewSegment: true),
      _point(45.4),
    ];

    final markers = computeWalkRouteMarkers(route, isFinished: true);

    expect(markers.pausePoints, [beforePause.coordinates]);
    expect(markers.finish, route.last.coordinates);
  });

  test('two pauses produce two pause markers, in order', () {
    final firstBreakPoint = _point(45.2);
    final secondBreakPoint = _point(45.3, startsNewSegment: true);
    final route = [
      _point(45.1),
      firstBreakPoint,
      secondBreakPoint,
      _point(45.4, startsNewSegment: true),
      _point(45.5),
    ];

    final markers = computeWalkRouteMarkers(route, isFinished: true);

    expect(markers.pausePoints, [firstBreakPoint.coordinates, secondBreakPoint.coordinates]);
  });
}
