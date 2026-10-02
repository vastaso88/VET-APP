import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/dog_walks/data/active_walk_controller.dart';
import 'package:vet_app_mobile/features/dog_walks/data/dog_walks_repository.dart';
import 'package:vet_app_mobile/features/dog_walks/domain/gps_fix.dart';
import 'package:vet_app_mobile/features/dog_walks/domain/walk_session.dart';
import 'package:vet_app_mobile/features/location/domain/coordinates.dart';

GpsFix _fix(double latitude, double longitude,
    {double accuracyMeters = 5, DateTime? recordedAt}) {
  return GpsFix(
    coordinates: Coordinates(latitude: latitude, longitude: longitude),
    recordedAt: recordedAt ?? DateTime.now(),
    accuracyMeters: accuracyMeters,
  );
}

void main() {
  test('estimateSteps mirrors the backend stride math', () {
    expect(estimateSteps(0), 0);
    expect(estimateSteps(75, strideMeters: 0.75), 100);
  });

  test('feeding synthetic GPS fixes accumulates distance and route length',
      () async {
    final controller = ActiveWalkController(repository: DogWalksRepository());
    final positionController = StreamController<GpsFix>();
    addTearDown(() async {
      await positionController.close();
      controller.dispose();
    });

    await controller.start(
      ownerId: 'user-1',
      petId: 'pet-1',
      positionStream: positionController.stream,
    );
    expect(controller.isActive, isTrue);

    final start = DateTime.now();
    positionController.add(_fix(45.4642, 9.1900, recordedAt: start));
    await Future<void>.delayed(Duration.zero);
    // A real GPS stream fires a few seconds apart (distanceFilter/interval),
    // not back-to-back - matching that here so the ~120m gap isn't flagged
    // as an impossible speed jump.
    positionController.add(_fix(45.4650, 9.1910,
        recordedAt: start.add(const Duration(seconds: 30))));
    await Future<void>.delayed(Duration.zero);

    expect(controller.walk!.route, hasLength(2));
    expect(controller.walk!.distanceMeters, greaterThan(0));

    await controller.stop();

    expect(controller.isActive, isFalse);
    expect(controller.walk!.status, WalkStatus.completed);
    expect(controller.walk!.endedAt, isNotNull);
    expect(controller.walk!.stepCountEstimate,
        estimateSteps(controller.walk!.distanceMeters));
  });

  test('points received after stop are ignored', () async {
    final controller = ActiveWalkController(repository: DogWalksRepository());
    final positionController = StreamController<GpsFix>();
    addTearDown(() async {
      await positionController.close();
      controller.dispose();
    });

    await controller.start(
      ownerId: 'user-1',
      petId: 'pet-1',
      positionStream: positionController.stream,
    );
    await controller.stop();
    final distanceAtStop = controller.walk!.distanceMeters;

    positionController.add(_fix(45.4642, 9.1900));
    await Future<void>.delayed(Duration.zero);

    expect(controller.walk!.distanceMeters, distanceAtStop);
    expect(controller.walk!.route, isEmpty);
  });

  test('the route does not start until a fix is accurate enough', () async {
    final controller = ActiveWalkController(repository: DogWalksRepository());
    final positionController = StreamController<GpsFix>();
    addTearDown(() async {
      await positionController.close();
      controller.dispose();
    });

    await controller.start(
      ownerId: 'user-1',
      petId: 'pet-1',
      positionStream: positionController.stream,
    );
    expect(controller.isAwaitingAccurateFix, isTrue);

    positionController.add(_fix(45.4642, 9.1900, accuracyMeters: 40));
    await Future<void>.delayed(Duration.zero);
    expect(controller.walk!.route, isEmpty,
        reason: '40m accuracy is worse than the 25m start gate');
    expect(controller.isAwaitingAccurateFix, isTrue);

    positionController.add(_fix(45.4642, 9.1900, accuracyMeters: 10));
    await Future<void>.delayed(Duration.zero);
    expect(controller.walk!.route, hasLength(1));
    expect(controller.isAwaitingAccurateFix, isFalse);
  });

  test('a fix worse than the accuracy ceiling is dropped mid-walk', () async {
    final controller = ActiveWalkController(repository: DogWalksRepository());
    final positionController = StreamController<GpsFix>();
    addTearDown(() async {
      await positionController.close();
      controller.dispose();
    });

    await controller.start(
      ownerId: 'user-1',
      petId: 'pet-1',
      positionStream: positionController.stream,
    );
    positionController.add(_fix(45.4642, 9.1900));
    await Future<void>.delayed(Duration.zero);

    positionController.add(_fix(45.4650, 9.1910, accuracyMeters: 80));
    await Future<void>.delayed(Duration.zero);

    expect(controller.walk!.route, hasLength(1));
  });

  test('an impossible speed jump between fixes is dropped', () async {
    final controller = ActiveWalkController(repository: DogWalksRepository());
    final positionController = StreamController<GpsFix>();
    addTearDown(() async {
      await positionController.close();
      controller.dispose();
    });

    final start = DateTime.now();
    await controller.start(
      ownerId: 'user-1',
      petId: 'pet-1',
      positionStream: positionController.stream,
    );
    positionController.add(_fix(45.4642, 9.1900, recordedAt: start));
    await Future<void>.delayed(Duration.zero);

    // ~1.1km a second later: no dog walk covers that - must be a GPS glitch.
    positionController.add(_fix(45.4740, 9.1900,
        recordedAt: start.add(const Duration(seconds: 1))));
    await Future<void>.delayed(Duration.zero);

    expect(controller.walk!.route, hasLength(1));
  });

  group('pause/resume', () {
    test('pause ignores GPS fixes until resume', () async {
      final controller = ActiveWalkController(repository: DogWalksRepository());
      final positionController = StreamController<GpsFix>();
      addTearDown(() async {
        await positionController.close();
        controller.dispose();
      });

      await controller.start(
        ownerId: 'user-1',
        petId: 'pet-1',
        positionStream: positionController.stream,
      );
      positionController.add(_fix(45.4642, 9.1900));
      await Future<void>.delayed(Duration.zero);
      expect(controller.walk!.route, hasLength(1));

      await controller.pause();
      expect(controller.walk!.isPaused, isTrue);

      positionController.add(_fix(45.4650, 9.1910));
      await Future<void>.delayed(Duration.zero);
      expect(controller.walk!.route, hasLength(1),
          reason: 'fixes while paused must not grow the route');
      expect(controller.walk!.distanceMeters, 0);
    });

    test('pause is a no-op when not tracking or already paused', () async {
      final controller = ActiveWalkController(repository: DogWalksRepository());
      await controller.pause();
      expect(controller.walk, isNull);
      addTearDown(controller.dispose);
    });

    test('resuming accepts the next fix as a new segment without a distance jump or '
        'speed-glitch rejection', () async {
      final controller = ActiveWalkController(repository: DogWalksRepository());
      final positionController = StreamController<GpsFix>();
      addTearDown(() async {
        await positionController.close();
        controller.dispose();
      });

      await controller.start(
        ownerId: 'user-1',
        petId: 'pet-1',
        positionStream: positionController.stream,
      );
      final start = DateTime.now();
      positionController.add(_fix(45.4642, 9.1900, recordedAt: start));
      await Future<void>.delayed(Duration.zero);

      await controller.pause();
      await controller.resume();
      expect(controller.walk!.isPaused, isFalse);

      // Miles away, a second after the pre-pause point by wall clock - would
      // fail the speed-jump check as a live fix, but resuming should treat
      // it as a fresh segment start instead.
      positionController.add(
        _fix(46.0, 10.0, recordedAt: start.add(const Duration(seconds: 1))),
      );
      await Future<void>.delayed(Duration.zero);

      expect(controller.walk!.route, hasLength(2));
      expect(controller.walk!.route.last.startsNewSegment, isTrue);
      expect(controller.walk!.route.first.startsNewSegment, isFalse);
      expect(controller.walk!.distanceMeters, 0,
          reason: 'the segment-start point adds no distance from the pre-pause point');
    });

    test('resume is a no-op when not paused', () async {
      final controller = ActiveWalkController(repository: DogWalksRepository());
      final positionController = StreamController<GpsFix>();
      addTearDown(() async {
        await positionController.close();
        controller.dispose();
      });

      await controller.start(
        ownerId: 'user-1',
        petId: 'pet-1',
        positionStream: positionController.stream,
      );
      await controller.resume();
      expect(controller.walk!.isPaused, isFalse);
      expect(controller.walk!.pausedSeconds, 0);
    });

    test('stop while paused folds the ongoing pause into the saved duration', () async {
      final controller = ActiveWalkController(repository: DogWalksRepository());
      final positionController = StreamController<GpsFix>();
      addTearDown(() async {
        await positionController.close();
        controller.dispose();
      });

      await controller.start(
        ownerId: 'user-1',
        petId: 'pet-1',
        positionStream: positionController.stream,
      );
      await controller.pause();

      await controller.stop();

      expect(controller.walk!.status, WalkStatus.completed);
      expect(controller.walk!.isPaused, isFalse);
      expect(controller.walk!.durationSeconds, isNotNull);
      expect(controller.walk!.durationSeconds, lessThanOrEqualTo(1));
    });
  });

  group('walkActiveDurationSeconds', () {
    test('excludes a completed pause interval', () {
      final start = DateTime(2026, 1, 1, 10);
      final walk = WalkSession(
        id: 'walk-1',
        ownerId: 'user-1',
        petId: 'pet-1',
        startedAt: start,
        pausedSeconds: 120,
      );

      final active =
          walkActiveDurationSeconds(walk, now: start.add(const Duration(minutes: 10)));

      expect(active, 10 * 60 - 120);
    });

    test('also excludes the pause currently in progress', () {
      final start = DateTime(2026, 1, 1, 10);
      final walk = WalkSession(
        id: 'walk-1',
        ownerId: 'user-1',
        petId: 'pet-1',
        startedAt: start,
        isPaused: true,
        pausedAt: start.add(const Duration(minutes: 8)),
      );

      final active =
          walkActiveDurationSeconds(walk, now: start.add(const Duration(minutes: 10)));

      // 10 minutes elapsed, but the last 2 were spent paused.
      expect(active, 8 * 60);
    });
  });

  group('public surface for other UI (widget/banner)', () {
    test('reflects no active walk', () {
      final controller = ActiveWalkController(repository: DogWalksRepository());
      addTearDown(controller.dispose);

      expect(controller.hasActiveWalk, isFalse);
      expect(controller.activePetId, isNull);
      expect(controller.activeDistanceMeters, 0);
      expect(controller.activeSeconds, 0);
      expect(controller.isPaused, isFalse);
    });

    test('reflects an in-progress walk', () async {
      final controller = ActiveWalkController(repository: DogWalksRepository());
      final positionController = StreamController<GpsFix>();
      addTearDown(() async {
        await positionController.close();
        controller.dispose();
      });

      await controller.start(
        ownerId: 'user-1',
        petId: 'pet-7',
        positionStream: positionController.stream,
      );
      positionController.add(_fix(45.4642, 9.1900));
      await Future<void>.delayed(Duration.zero);

      expect(controller.hasActiveWalk, isTrue);
      expect(controller.activePetId, 'pet-7');
      expect(controller.isPaused, isFalse);

      await controller.pause();
      expect(controller.isPaused, isTrue);
    });
  });
}
