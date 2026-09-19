import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/dog_walks/data/active_walk_controller.dart';
import 'package:vet_app_mobile/features/dog_walks/data/dog_walks_repository.dart';
import 'package:vet_app_mobile/features/dog_walks/domain/walk_session.dart';
import 'package:vet_app_mobile/features/location/domain/coordinates.dart';

void main() {
  test('estimateSteps mirrors the backend stride math', () {
    expect(estimateSteps(0), 0);
    expect(estimateSteps(75, strideMeters: 0.75), 100);
  });

  test('feeding synthetic GPS points accumulates distance and route length', () async {
    final controller = ActiveWalkController(repository: DogWalksRepository());
    final positionController = StreamController<Coordinates>();
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

    positionController.add(const Coordinates(latitude: 45.4642, longitude: 9.1900));
    await Future<void>.delayed(Duration.zero);
    positionController.add(const Coordinates(latitude: 45.4650, longitude: 9.1910));
    await Future<void>.delayed(Duration.zero);

    expect(controller.walk!.route, hasLength(2));
    expect(controller.walk!.distanceMeters, greaterThan(0));

    await controller.stop();

    expect(controller.isActive, isFalse);
    expect(controller.walk!.status, WalkStatus.completed);
    expect(controller.walk!.endedAt, isNotNull);
    expect(controller.walk!.stepCountEstimate, estimateSteps(controller.walk!.distanceMeters));
  });

  test('points received after stop are ignored', () async {
    final controller = ActiveWalkController(repository: DogWalksRepository());
    final positionController = StreamController<Coordinates>();
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

    positionController.add(const Coordinates(latitude: 45.4642, longitude: 9.1900));
    await Future<void>.delayed(Duration.zero);

    expect(controller.walk!.distanceMeters, distanceAtStop);
    expect(controller.walk!.route, isEmpty);
  });
}
