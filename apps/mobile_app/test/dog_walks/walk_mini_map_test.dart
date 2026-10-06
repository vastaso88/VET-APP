import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/dog_walks/domain/walk_map_framing.dart';
import 'package:vet_app_mobile/features/dog_walks/domain/walk_session.dart';
import 'package:vet_app_mobile/features/dog_walks/presentation/widgets/walk_mini_map.dart';
import 'package:vet_app_mobile/features/location/domain/coordinates.dart';

RoutePoint _point(double latitude, double longitude) => RoutePoint(
      coordinates: Coordinates(latitude: latitude, longitude: longitude),
      recordedAt: DateTime(2026, 1, 1),
    );

WalkSession _walk(String id, List<RoutePoint> route) => WalkSession(
      id: id,
      ownerId: 'o',
      petId: 'p',
      status: WalkStatus.completed,
      startedAt: DateTime(2026, 1, 1),
      distanceMeters: 500,
      route: route,
    );

/// ~1.5 km walk in Milan.
final _longRoute = [
  _point(45.4642, 9.1900),
  _point(45.4700, 9.1950),
  _point(45.4780, 9.2050),
];

/// A different walk elsewhere in the city.
final _otherRoute = [
  _point(45.4400, 9.1500),
  _point(45.4430, 9.1560),
  _point(45.4460, 9.1600),
];

void main() {
  group('walkMapFrame', () {
    test('is null for an empty or single-point route (nothing to draw)', () {
      expect(walkMapFrame(const []), isNull);
      expect(walkMapFrame([_point(45.0, 9.0)]), isNull);
    });

    test('wraps a long route and is centered on it', () {
      final frame = walkMapFrame(_longRoute)!;

      expect(frame.south, 45.4642);
      expect(frame.north, 45.4780);
      expect(frame.west, 9.1900);
      expect(frame.east, 9.2050);
    });

    test('different walks get different frames', () {
      expect(walkMapFrame(_longRoute), isNot(walkMapFrame(_otherRoute)));
    });

    test('a very short walk is widened to the minimum span, not left as a dot', () {
      // ~11 m of walking.
      final frame = walkMapFrame([_point(45.46420, 9.19000), _point(45.46430, 9.19000)])!;

      final latitudeMeters = (frame.north - frame.south) * 111320;
      expect(latitudeMeters, closeTo(250, 1));
      final longitudeMeters = (frame.east - frame.west) * 111320 * 0.7; // cos(45.46 deg)
      expect(longitudeMeters, closeTo(250, 5));
      expect(frame.centerLatitude, closeTo(45.46425, 1e-6));
      expect(frame.centerLongitude, closeTo(9.19, 1e-6));
    });

    test('a long walk is never shrunk below its own bounds', () {
      final frame = walkMapFrame(_longRoute, minSpanMeters: 100)!;

      expect(frame.north - frame.south, greaterThanOrEqualTo(45.4780 - 45.4642));
    });
  });

  group('WalkMiniMap', () {
    Future<CameraFit?> fitOf(WidgetTester tester, WalkSession walk) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(width: 360, height: 150, child: WalkMiniMap(walk: walk)),
        ),
      );
      return tester.widget<FlutterMap>(find.byType(FlutterMap)).options.initialCameraFit;
    }

    testWidgets('each walk frames its own route', (tester) async {
      final first = await fitOf(tester, _walk('a', _longRoute)) as FitBounds;
      final second = await fitOf(tester, _walk('b', _otherRoute)) as FitBounds;

      expect(first.bounds.south, closeTo(45.4642, 1e-9));
      expect(second.bounds.south, closeTo(45.4400, 1e-9));
      expect(first.bounds, isNot(second.bounds));
    });

    testWidgets('a card reused for another walk builds a fresh, correctly framed map',
        (tester) async {
      // Same widget slot, walk A replaced by walk B - as a list does after a
      // delete or a reload. Without a key carrying the walk id the map State
      // (and its one-time camera) would be reused and keep showing walk A.
      await tester.pumpWidget(MaterialApp(
        home: SizedBox(width: 360, height: 150, child: WalkMiniMap(walk: _walk('a', _longRoute))),
      ));
      final before = tester.widget<FlutterMap>(find.byType(FlutterMap)).key;

      await tester.pumpWidget(MaterialApp(
        home: SizedBox(width: 360, height: 150, child: WalkMiniMap(walk: _walk('b', _otherRoute))),
      ));
      final after = tester.widget<FlutterMap>(find.byType(FlutterMap));

      expect(after.key, isNot(before));
      expect((after.options.initialCameraFit! as FitBounds).bounds.south, closeTo(45.4400, 1e-9));
    });

    testWidgets('an empty route shows "Percorso non disponibile", not a map with a flag',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SizedBox(width: 360, height: 150, child: WalkMiniMap(walk: _walk('x', const []))),
      ));

      expect(find.text('Percorso non disponibile'), findsOneWidget);
      expect(find.byType(FlutterMap), findsNothing);
    });

    testWidgets('a single point is also "not available"', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SizedBox(
          width: 360,
          height: 150,
          child: WalkMiniMap(walk: _walk('x', [_point(45.4, 9.1)])),
        ),
      ));

      expect(find.text('Percorso non disponibile'), findsOneWidget);
    });
  });
}
