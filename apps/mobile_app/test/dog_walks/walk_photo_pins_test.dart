import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/dog_walks/domain/walk_photo_pins.dart';
import 'package:vet_app_mobile/features/dog_walks/domain/walk_session.dart';
import 'package:vet_app_mobile/features/location/domain/coordinates.dart';

final _t0 = DateTime.utc(2026, 10, 9, 8, 0);

RoutePoint _point(int minute, double latitude, double longitude, {bool newSegment = false}) {
  return RoutePoint(
    coordinates: Coordinates(latitude: latitude, longitude: longitude),
    recordedAt: _t0.add(Duration(minutes: minute)),
    startsNewSegment: newSegment,
  );
}

WalkSession _walk(List<RoutePoint> route, {WalkStatus status = WalkStatus.completed}) {
  return WalkSession(
    id: 'w1',
    ownerId: 'o',
    petId: 'p',
    status: status,
    startedAt: _t0,
    endedAt: _t0.add(const Duration(minutes: 10)),
    route: route,
  );
}

void main() {
  // 0 min: (45.00, 9.00)  ->  10 min: (45.10, 9.20), a straight line.
  final straight = [_point(0, 45.00, 9.00), _point(10, 45.10, 9.20)];

  group('routePositionAt', () {
    test('is null for an empty route', () {
      expect(routePositionAt(const [], _t0), isNull);
    });

    test('halfway in time is halfway along the line', () {
      final at = routePositionAt(straight, _t0.add(const Duration(minutes: 5)))!;

      expect(at.latitude, closeTo(45.05, 1e-9));
      expect(at.longitude, closeTo(9.10, 1e-9));
    });

    test('interpolates between the two points that surround the moment', () {
      final route = [
        _point(0, 45.00, 9.00),
        _point(2, 45.02, 9.00),
        _point(6, 45.02, 9.08), // slower stretch east
        _point(10, 45.10, 9.08),
      ];

      final at = routePositionAt(route, _t0.add(const Duration(minutes: 3)))!;

      expect(at.latitude, closeTo(45.02, 1e-9));
      expect(at.longitude, closeTo(9.02, 1e-9), reason: '1 of the 4 minutes of the eastbound leg');
    });

    test('exactly on a recorded point is that point', () {
      final at = routePositionAt(straight, _t0.add(const Duration(minutes: 10)))!;

      expect(at.latitude, 45.10);
      expect(at.longitude, 9.20);
    });

    test('before the first fix is the first point, after the last is the last', () {
      expect(routePositionAt(straight, _t0.subtract(const Duration(minutes: 3)))!.latitude, 45.00);
      expect(routePositionAt(straight, _t0.add(const Duration(minutes: 30)))!.latitude, 45.10);
    });

    test('a single point is that point', () {
      final at = routePositionAt([_point(0, 45.5, 9.5)], _t0.add(const Duration(minutes: 1)))!;

      expect(at.latitude, 45.5);
    });

    test('across a pause the answer is where the walker stopped, not a line over unwalked ground', () {
      final route = [
        _point(0, 45.00, 9.00),
        _point(3, 45.03, 9.00), // paused here
        _point(8, 45.50, 9.50, newSegment: true), // resumed far away (e.g. after a car ride)
        _point(10, 45.52, 9.52),
      ];

      final during = routePositionAt(route, _t0.add(const Duration(minutes: 5)))!;

      expect(during.latitude, 45.03);
      expect(during.longitude, 9.00);
    });

    test('two points with the same timestamp do not divide by zero', () {
      final route = [_point(0, 45.0, 9.0), _point(5, 45.1, 9.1), _point(5, 45.2, 9.2), _point(10, 45.3, 9.3)];

      final at = routePositionAt(route, _t0.add(const Duration(minutes: 5)))!;

      expect(at.latitude.isNaN, isFalse);
    });

    test('the moment can be given in any zone', () {
      final local = _t0.add(const Duration(minutes: 5)).toLocal();

      final at = routePositionAt(straight, local)!;

      expect(at.latitude, closeTo(45.05, 1e-9));
    });
  });

  group('walkPhotoPins', () {
    ({String id, DateTime? takenAt}) photo(String id, int? minute) =>
        (id: id, takenAt: minute == null ? null : _t0.add(Duration(minutes: minute)));

    test('one pin per photo taken during the walk, oldest first', () {
      final pins = walkPhotoPins(_walk(straight), [photo('late', 8), photo('early', 2)]);

      expect(pins.map((pin) => pin.photoId), ['early', 'late']);
      expect(pins.first.at.latitude, closeTo(45.02, 1e-9));
      expect(pins.last.at.latitude, closeTo(45.08, 1e-9));
    });

    test('photos outside the walk are ignored', () {
      final pins = walkPhotoPins(
        _walk(straight),
        [photo('before', -5), photo('after', 25), photo('during', 4)],
      );

      expect(pins.map((pin) => pin.photoId), ['during']);
    });

    test('a photo with no shooting time is ignored', () {
      expect(walkPhotoPins(_walk(straight), [photo('unknown', null)]), isEmpty);
    });

    test('the very start and end of the walk count', () {
      final pins = walkPhotoPins(_walk(straight), [photo('start', 0), photo('end', 10)]);

      expect(pins, hasLength(2));
    });

    test('a walk without a recorded route (cleaned up) has no pins', () {
      expect(walkPhotoPins(_walk(const []), [photo('during', 4)]), isEmpty);
    });

    test('a discarded walk has no pins', () {
      expect(
        walkPhotoPins(_walk(straight, status: WalkStatus.discarded), [photo('during', 4)]),
        isEmpty,
      );
    });

    test('several photos at the same moment all get a pin', () {
      final pins = walkPhotoPins(_walk(straight), [photo('a', 5), photo('b', 5)]);

      expect(pins, hasLength(2));
      expect(pins[0].at.latitude, pins[1].at.latitude);
    });

    test('works with photo times in local time, as the database parses them in UTC', () {
      final pins = walkPhotoPins(
        _walk(straight),
        [(id: 'x', takenAt: _t0.add(const Duration(minutes: 5)).toLocal())],
      );

      expect(pins, hasLength(1));
    });
  });
}
