import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/dog_walks/domain/walk_route_segments.dart';
import 'package:vet_app_mobile/features/dog_walks/domain/walk_session.dart';
import 'package:vet_app_mobile/features/location/domain/coordinates.dart';

RoutePoint _point(int minute, {bool startsNewSegment = false}) {
  return RoutePoint(
    coordinates: const Coordinates(latitude: 45.46, longitude: 9.19),
    recordedAt: DateTime(2026, 1, 1, 10, minute),
    startsNewSegment: startsNewSegment,
  );
}

void main() {
  test('an empty route has no segments', () {
    expect(splitRouteIntoSegments(const []), isEmpty);
  });

  test('a route with no breaks is a single segment', () {
    final route = [_point(0), _point(1), _point(2)];

    expect(splitRouteIntoSegments(route), [route]);
  });

  test('a startsNewSegment point begins a new segment', () {
    final route = [
      _point(0),
      _point(1),
      _point(5, startsNewSegment: true),
      _point(6),
    ];

    final segments = splitRouteIntoSegments(route);

    expect(segments, hasLength(2));
    expect(segments[0], [route[0], route[1]]);
    expect(segments[1], [route[2], route[3]]);
  });

  test('two consecutive pauses produce three segments', () {
    final route = [
      _point(0),
      _point(1, startsNewSegment: true),
      _point(2, startsNewSegment: true),
    ];

    final segments = splitRouteIntoSegments(route);

    expect(segments, hasLength(3));
    expect(segments.map((segment) => segment.length), [1, 1, 1]);
  });
}
