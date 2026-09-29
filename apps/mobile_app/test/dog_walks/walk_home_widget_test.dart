import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/dog_walks/data/active_walk_controller.dart';
import 'package:vet_app_mobile/features/dog_walks/data/dog_walks_repository.dart';
import 'package:vet_app_mobile/features/dog_walks/data/walk_home_widget.dart';
import 'package:vet_app_mobile/features/dog_walks/domain/gps_fix.dart';
import 'package:vet_app_mobile/features/location/domain/coordinates.dart';

GpsFix _fix(double latitude, double longitude, DateTime recordedAt) {
  return GpsFix(
    coordinates: Coordinates(latitude: latitude, longitude: longitude),
    recordedAt: recordedAt,
    accuracyMeters: 5,
  );
}

void main() {
  test('isDogSpecies matches only dogs, ignoring case/whitespace', () {
    expect(isDogSpecies('Cane'), isTrue);
    expect(isDogSpecies(' cane '), isTrue);
    expect(isDogSpecies('Gatto'), isFalse);
    expect(isDogSpecies(''), isFalse);
  });

  test('formatWidgetDistance uses one decimal and an Italian comma', () {
    expect(formatWidgetDistance(0), '0,0 km');
    expect(formatWidgetDistance(-5), '0,0 km');
    expect(formatWidgetDistance(1300), '1,3 km');
    expect(formatWidgetDistance(12345), '12,3 km');
  });

  group('ActiveWalkWidgetPublisher', () {
    late ActiveWalkController controller;
    late StreamController<GpsFix> gps;
    late DateTime now;
    late List<ActiveWalkWidgetSnapshot?> published;

    setUp(() {
      controller = ActiveWalkController(repository: DogWalksRepository());
      gps = StreamController<GpsFix>();
      now = DateTime(2026, 9, 30, 10);
      published = [];
    });

    tearDown(() async {
      // Not awaited: a controller nobody listened to never completes close().
      unawaited(gps.close());
      controller.dispose();
    });

    ActiveWalkWidgetPublisher makePublisher({
      Duration throttle = const Duration(seconds: 7),
      DateTime Function()? clock,
    }) {
      return ActiveWalkWidgetPublisher(
        controller: controller,
        throttle: throttle,
        clock: clock ?? () => now,
        publish: (snapshot) async => published.add(snapshot),
      );
    }

    Future<void> feed(double lat, double lon, DateTime at) async {
      gps.add(_fix(lat, lon, at));
      await Future<void>.delayed(Duration.zero);
    }

    test('idle app publishes one clearing update, then stays quiet', () {
      final publisher = makePublisher()..attach();
      expect(published, [null]);
      // ignore: invalid_use_of_protected_member
      controller.notifyListeners();
      expect(published, [null]);
      publisher.detach();
    });

    test('lifecycle changes go out at once, distance updates are throttled',
        () async {
      final publisher = makePublisher()..attach();
      published.clear();

      await controller.start(
          ownerId: 'u1', petId: 'pet-1', positionStream: gps.stream);
      expect(published, hasLength(1));
      expect(published.last?.petId, 'pet-1');
      expect(published.last?.isPaused, isFalse);

      // First accepted fix, right after the start publish: inside the window.
      now = now.add(const Duration(seconds: 2));
      await feed(45.4642, 9.1900, now);
      expect(published, hasLength(1));

      // Window elapsed: the next fix publishes with the fresh distance.
      now = now.add(const Duration(seconds: 8));
      await feed(45.46455, 9.1904, now);
      expect(published, hasLength(2));
      expect(published.last!.distanceMeters, greaterThan(0));
      expect(published.last!.toJson()['distanceLabel'], contains(' km'));

      // Another fix 1s later: throttled.
      now = now.add(const Duration(seconds: 1));
      await feed(45.4652, 9.1912, now);
      expect(published, hasLength(2));

      // Pause / resume bypass the throttle.
      await controller.pause();
      expect(published, hasLength(3));
      expect(published.last?.isPaused, isTrue);
      await controller.resume();
      expect(published, hasLength(4));
      expect(published.last?.isPaused, isFalse);

      // Stop clears the widget immediately, and only once.
      await controller.stop();
      expect(published, hasLength(5));
      expect(published.last, isNull);
      // ignore: invalid_use_of_protected_member
      controller.notifyListeners();
      expect(published, hasLength(5));

      publisher.detach();
    });

    test('a throttled update is published later by the trailing timer',
        () async {
      final publisher = makePublisher(
        throttle: const Duration(milliseconds: 40),
        clock: DateTime.now,
      )..attach();
      published.clear();

      await controller.start(
          ownerId: 'u1', petId: 'pet-1', positionStream: gps.stream);
      final t0 = DateTime.now();
      await feed(45.4642, 9.1900, t0);
      await feed(45.4650, 9.1910, t0.add(const Duration(seconds: 30)));
      expect(published, hasLength(1));

      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(published, hasLength(2));
      expect(published.last!.distanceMeters, greaterThan(0));

      publisher.detach();
    });
  });
}
