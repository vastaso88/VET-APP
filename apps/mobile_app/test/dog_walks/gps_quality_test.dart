import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/dog_walks/domain/gps_fix.dart';
import 'package:vet_app_mobile/features/dog_walks/domain/gps_quality.dart';
import 'package:vet_app_mobile/features/dog_walks/domain/walk_session.dart';
import 'package:vet_app_mobile/features/location/domain/coordinates.dart';

void main() {
  group('isFixAccurateEnoughToStart', () {
    test('true at or under the start-accuracy threshold', () {
      final fix = GpsFix(
        coordinates: const Coordinates(latitude: 45.46, longitude: 9.19),
        recordedAt: DateTime.now(),
        accuracyMeters: walkMinStartAccuracyMeters,
      );
      expect(isFixAccurateEnoughToStart(fix), isTrue);
    });

    test('false when worse than the threshold or unknown', () {
      final imprecise = GpsFix(
        coordinates: const Coordinates(latitude: 45.46, longitude: 9.19),
        recordedAt: DateTime.now(),
        accuracyMeters: walkMinStartAccuracyMeters + 1,
      );
      final unknown = GpsFix(
        coordinates: const Coordinates(latitude: 45.46, longitude: 9.19),
        recordedAt: DateTime.now(),
      );
      expect(isFixAccurateEnoughToStart(imprecise), isFalse);
      expect(isFixAccurateEnoughToStart(unknown), isFalse);
    });
  });

  group('filterAndSmoothFix', () {
    test('accepts the first point of a route as-is', () {
      final fix = GpsFix(
        coordinates: const Coordinates(latitude: 45.4642, longitude: 9.1900),
        recordedAt: DateTime.now(),
        accuracyMeters: 10,
      );
      final point = filterAndSmoothFix(fix, null);
      expect(point!.coordinates, fix.coordinates);
    });

    test('drops a fix worse than the acceptable-accuracy ceiling', () {
      final fix = GpsFix(
        coordinates: const Coordinates(latitude: 45.4642, longitude: 9.1900),
        recordedAt: DateTime.now(),
        accuracyMeters: walkMaxAcceptableAccuracyMeters + 1,
      );
      expect(filterAndSmoothFix(fix, null), isNull);
    });

    test('drops an implausibly fast jump from the last accepted point', () {
      final start = DateTime.now();
      final last = RoutePoint(
        coordinates: const Coordinates(latitude: 45.4642, longitude: 9.1900),
        recordedAt: start,
      );
      // ~1.1km a second later.
      final fix = GpsFix(
        coordinates: const Coordinates(latitude: 45.4740, longitude: 9.1900),
        recordedAt: start.add(const Duration(seconds: 1)),
        accuracyMeters: 10,
      );
      expect(filterAndSmoothFix(fix, last), isNull);
    });

    test('smooths a plausible move partway toward the raw fix', () {
      final start = DateTime.now();
      final last = RoutePoint(
        coordinates: const Coordinates(latitude: 45.4642, longitude: 9.1900),
        recordedAt: start,
      );
      final fix = GpsFix(
        // ~55m over 10s (5.5 m/s) - a brisk walk, well under the speed gate.
        coordinates: const Coordinates(latitude: 45.4647, longitude: 9.1900),
        recordedAt: start.add(const Duration(seconds: 10)),
        accuracyMeters: 10,
      );

      final point = filterAndSmoothFix(fix, last)!;

      // Smoothed latitude sits strictly between the last accepted point and
      // the raw fix - neither ignored nor taken verbatim.
      expect(
          point.coordinates.latitude, greaterThan(last.coordinates.latitude));
      expect(point.coordinates.latitude, lessThan(fix.coordinates.latitude));
    });
  });
}
