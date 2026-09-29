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
}
