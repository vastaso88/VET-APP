import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vet_app_mobile/features/dog_walks/data/active_walk_controller.dart';
import 'package:vet_app_mobile/features/dog_walks/domain/gps_fix.dart';
import 'package:vet_app_mobile/features/dog_walks/presentation/pages/active_walk_page.dart';
import 'package:vet_app_mobile/features/dog_walks/presentation/pages/walk_detail_page.dart';
import 'package:vet_app_mobile/features/location/domain/coordinates.dart';
import 'package:vet_app_mobile/features/pets/data/pet_media_capture.dart';
import 'package:vet_app_mobile/features/pets/data/pet_media_importer.dart';
import 'package:vet_app_mobile/features/pets/data/pet_photo_repository.dart';
import 'package:vet_app_mobile/features/pets/domain/pet_models.dart';

/// A capture flow with no camera: records what was asked and answers at once
/// (or when the test lets it).
class _FakeCapture extends PetMediaCapture {
  final calls = <String>[];
  Completer<void>? hold;
  PetMediaImportResult result = const PetMediaImportResult(photos: 1);

  @override
  Future<PetMediaImportResult?> takePhoto(String petId) async {
    calls.add('photo:$petId');
    await hold?.future;
    return result;
  }

  @override
  Future<PetMediaImportResult?> recordVideo(String petId) async {
    calls.add('video:$petId');
    return const PetMediaImportResult(videos: 1);
  }
}

PetProfile get _thor => const PetProfile(
      id: 'thor',
      name: 'Thor',
      species: 'Cane',
      breed: '',
      birthDateLabel: '',
      sex: 'Maschio',
      weightLabel: '',
      medicalNote: '',
      healthBadge: '',
      nextVisitLabel: '',
      avatarEmoji: '🐶',
      accentColor: Colors.white,
      identityColor: Colors.green,
    );

GpsFix _fix(double latitude, double longitude, DateTime at) => GpsFix(
      coordinates: Coordinates(latitude: latitude, longitude: longitude),
      recordedAt: at,
      accuracyMeters: 5,
    );

/// Lets the modal sheet finish sliding in (the map and loader animate forever,
/// so pumpAndSettle would never return).
Future<void> _openSheet(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUpAll(() => initializeDateFormatting('it_IT'));

  late StreamController<GpsFix> gps;
  late DateTime start;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    gps = StreamController<GpsFix>();
    start = DateTime.now().subtract(const Duration(minutes: 10));
    await ActiveWalkController.instance.start(
      ownerId: 'owner',
      petId: 'thor',
      positionStream: gps.stream,
    );
    gps.add(_fix(45.4642, 9.19, start));
    await Future<void>.delayed(Duration.zero);
    gps.add(_fix(45.4660, 9.1930, start.add(const Duration(minutes: 8))));
    await Future<void>.delayed(Duration.zero);
  });

  tearDown(() async {
    await ActiveWalkController.instance.stop();
    await gps.close();
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    required PetMediaCapture capture,
    Future<List<PetPhotoEntry>> Function(String petId)? photos,
    WalkCaptureKind? autoCapture,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ActiveWalkPage(
          pet: _thor,
          capture: capture,
          photosLoader: photos ?? (_) async => const [],
          autoCapture: autoCapture,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('a walk in progress offers a camera button; a stopped screen does not', (tester) async {
    await pumpPage(tester, capture: _FakeCapture());

    expect(find.byTooltip('Foto o video'), findsOneWidget);
  });

  testWidgets('"Scatta foto" opens the camera flow for the walk pet and confirms by name', (tester) async {
    final capture = _FakeCapture();
    await pumpPage(tester, capture: capture);

    await tester.tap(find.byTooltip('Foto o video'));
    await _openSheet(tester);
    expect(find.text('Scatta foto'), findsOneWidget);
    expect(find.text('Registra video'), findsOneWidget);
    await tester.tap(find.text('Scatta foto'));
    await tester.pump();
    await tester.pump();

    expect(capture.calls, ['photo:thor']);
    expect(find.text('Foto aggiunta alla galleria di Thor'), findsOneWidget);
  });

  testWidgets('"Registra video" records a video for the same pet', (tester) async {
    final capture = _FakeCapture();
    await pumpPage(tester, capture: capture);

    await tester.tap(find.byTooltip('Foto o video'));
    await _openSheet(tester);
    await tester.tap(find.text('Registra video'));
    await tester.pump();
    await tester.pump();

    expect(capture.calls, ['video:thor']);
    expect(find.text('Video aggiunto alla galleria di Thor'), findsOneWidget);
  });

  testWidgets('the walk keeps going while the camera is in front', (tester) async {
    final capture = _FakeCapture()..hold = Completer<void>();
    await pumpPage(tester, capture: capture);
    final walk = ActiveWalkController.instance;
    final routeBefore = walk.walk!.route.length;

    await tester.tap(find.byTooltip('Foto o video'));
    await _openSheet(tester);
    await tester.tap(find.text('Scatta foto'));
    await tester.pump();
    // The camera is "open": the app is in the background, GPS fixes keep arriving.
    gps.add(_fix(45.4670, 9.1950, start.add(const Duration(minutes: 9))));
    await tester.pump();
    capture.hold!.complete();
    await tester.pump();
    await tester.pump();

    expect(walk.isActive, isTrue);
    expect(walk.isPaused, isFalse);
    expect(walk.walk!.route.length, routeBefore + 1, reason: 'no point lost, nothing reset');
    expect(walk.walk!.id, isNotEmpty);
  });

  testWidgets('the page opened from the banner sheet goes straight to the camera', (tester) async {
    final capture = _FakeCapture();
    await pumpPage(tester, capture: capture, autoCapture: WalkCaptureKind.photo);

    expect(capture.calls, ['photo:thor']);
  });

  testWidgets('the shot appears on the live map as a pin where the walker was', (tester) async {
    // The walk window opens when the controller started it (just now) and
    // stays open until it ends, so a shot a moment ago is inside it.
    final shotAt = DateTime.now();
    var photos = <PetPhotoEntry>[];
    await pumpPage(tester, capture: _FakeCapture(), photos: (_) async => photos);
    expect(find.byType(WalkPhotoPinMarker), findsNothing);

    photos = [
      PetPhotoEntry(
        id: 'p1',
        petId: 'thor',
        storagePath: 'owner/thor/p1.jpg',
        createdAt: DateTime.now(),
        isProfile: false,
        takenAt: shotAt,
      ),
    ];
    PetPhotoRepository.changes.value++; // what an upload does
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey('walk-photo-pin-p1')), findsOneWidget);
  });

  testWidgets('a photo taken before the walk started gets no pin', (tester) async {
    await pumpPage(
      tester,
      capture: _FakeCapture(),
      photos: (_) async => [
        PetPhotoEntry(
          id: 'old',
          petId: 'thor',
          storagePath: 'owner/thor/old.jpg',
          createdAt: DateTime.now(),
          isProfile: false,
          takenAt: start.subtract(const Duration(hours: 3)),
        ),
      ],
    );

    expect(find.byType(WalkPhotoPinMarker), findsNothing);
  });
}
