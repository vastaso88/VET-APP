import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:vet_app_mobile/features/dog_walks/presentation/pages/walk_detail_page.dart';
import 'package:vet_app_mobile/features/dog_walks/presentation/widgets/walk_mini_map.dart';
import 'package:vet_app_mobile/features/dog_walks/domain/walk_session.dart';
import 'package:vet_app_mobile/features/location/domain/coordinates.dart';
import 'package:vet_app_mobile/features/pets/data/pet_photo_repository.dart';
import 'package:vet_app_mobile/features/pets/domain/pet_video_rules.dart';
import 'package:vet_app_mobile/features/pets/presentation/pages/pet_gallery_page.dart';

final _start = DateTime.utc(2026, 10, 9, 8, 0);

WalkSession _walk() {
  RoutePoint point(int minute, double latitude, double longitude) => RoutePoint(
        coordinates: Coordinates(latitude: latitude, longitude: longitude),
        recordedAt: _start.add(Duration(minutes: minute)),
      );
  return WalkSession(
    id: 'w1',
    ownerId: 'o',
    petId: 'pet-1',
    status: WalkStatus.completed,
    startedAt: _start,
    endedAt: _start.add(const Duration(minutes: 9)),
    distanceMeters: 401,
    durationSeconds: 540,
    route: [point(0, 45.4642, 9.19), point(5, 45.4670, 9.1950), point(9, 45.4700, 9.2000)],
  );
}

PetPhotoEntry _photo(String id, DateTime? takenAt, {bool video = false}) => PetPhotoEntry(
      id: id,
      petId: 'pet-1',
      storagePath: 'owner/pet-1/$id.jpg',
      createdAt: DateTime.utc(2026, 10, 9, 12),
      isProfile: false,
      takenAt: takenAt,
      kind: video ? PetMediaKind.video : PetMediaKind.photo,
    );

Future<void> _pump(WidgetTester tester, WalkPhotosLoader loader) async {
  await tester.pumpWidget(
    MaterialApp(
      home: WalkDetailPage(walk: _walk(), petName: 'Thor', photosLoader: loader),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  setUpAll(() => initializeDateFormatting('it_IT'));

  testWidgets('a photo taken during the walk gets a pin on the map and is counted', (tester) async {
    await _pump(tester, (_) async => [_photo('during', _start.add(const Duration(minutes: 4)))]);

    expect(find.byKey(const ValueKey('walk-photo-pin-during')), findsOneWidget);
    expect(find.text('Foto'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('several photos give several pins', (tester) async {
    await _pump(
      tester,
      (_) async => [
        _photo('a', _start.add(const Duration(minutes: 1))),
        _photo('b', _start.add(const Duration(minutes: 7))),
      ],
    );

    expect(find.byKey(const ValueKey('walk-photo-pin-a')), findsOneWidget);
    expect(find.byKey(const ValueKey('walk-photo-pin-b')), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('photos outside the walk, undated, or videos get no pin', (tester) async {
    await _pump(
      tester,
      (_) async => [
        _photo('before', _start.subtract(const Duration(minutes: 30))),
        _photo('after', _start.add(const Duration(hours: 2))),
        _photo('undated', null),
        _photo('clip', _start.add(const Duration(minutes: 3)), video: true),
      ],
    );

    expect(find.byType(WalkPhotoPinMarker), findsNothing);
    expect(find.text('Foto'), findsNothing);
  });

  testWidgets('the page still opens when the photos cannot be loaded', (tester) async {
    await _pump(tester, (_) async => throw Exception('offline'));

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byType(WalkPhotoPinMarker), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the pin sits where the walker was when the photo was taken', (tester) async {
    await _pump(tester, (_) async => [_photo('mid', _start.add(const Duration(minutes: 5)))]);

    // 5 minutes in is exactly the middle recorded point: the pin is a
    // marker of the map (a child of its marker layer), not a loose overlay.
    final pin = find.byKey(const ValueKey('walk-photo-pin-mid'));
    expect(pin, findsOneWidget);
    expect(find.ancestor(of: pin, matching: find.byType(MarkerLayer)), findsOneWidget);
    final marker = tester
        .widget<MarkerLayer>(find.ancestor(of: pin, matching: find.byType(MarkerLayer)))
        .markers
        .single;
    expect(marker.point.latitude, closeTo(45.4670, 1e-9));
    expect(marker.point.longitude, closeTo(9.1950, 1e-9));
  });

  testWidgets('tapping a pin opens the photo viewer', (tester) async {
    await _pump(tester, (_) async => [_photo('during', _start.add(const Duration(minutes: 4)))]);

    await tester.tap(find.byKey(const ValueKey('walk-photo-pin-during')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(PetPhotoViewerPage), findsOneWidget);
    expect(
      tester.widget<PetPhotoViewerPage>(find.byType(PetPhotoViewerPage)).storagePath,
      'owner/pet-1/during.jpg',
    );
  });

  testWidgets('the history thumbnail shows a dot for each photo place', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 360,
          height: 150,
          child: WalkMiniMap(
            walk: _walk(),
            photoPoints: const [
              Coordinates(latitude: 45.4650, longitude: 9.1910),
              Coordinates(latitude: 45.4690, longitude: 9.1990),
            ],
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey('walk-mini-photo-dot')), findsNWidgets(2));
  });

  testWidgets('no photo, no dots', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: SizedBox(width: 360, height: 150, child: WalkMiniMap(walk: _walk()))),
    );

    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey('walk-mini-photo-dot')), findsNothing);
    expect(find.byType(FlutterMap), findsOneWidget, reason: 'the map is there, just no dots');
  });
}
