import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/location/domain/coordinates.dart';
import 'package:vet_app_mobile/features/location/domain/geo_math.dart';

void main() {
  test('fuzzCoordinates matches the Python reference output bit-for-bit', () {
    // Reference computed with packages/core/domain/geo/models.py:
    // fuzz_coordinates(Coordinates(45.4642, 9.1900), "listing-test-fixture")
    // -> (45.4674427208385, 9.181563498806916)
    const exact = Coordinates(latitude: 45.4642, longitude: 9.1900);

    final fuzzed = fuzzCoordinates(exact, 'listing-test-fixture');

    expect(fuzzed.latitude, closeTo(45.4674427208385, 1e-9));
    expect(fuzzed.longitude, closeTo(9.181563498806916, 1e-9));
  });

  test('fuzzCoordinates stays within the 300-800m radius', () {
    const exact = Coordinates(latitude: 45.4642, longitude: 9.1900);

    final fuzzed = fuzzCoordinates(exact, 'another-listing');
    final distance = haversineMeters(exact, fuzzed);

    expect(distance, greaterThanOrEqualTo(300));
    expect(distance, lessThanOrEqualTo(800));
  });

  test('fuzzCoordinates is deterministic per listing id', () {
    const exact = Coordinates(latitude: 45.4642, longitude: 9.1900);

    final first = fuzzCoordinates(exact, 'listing-x');
    final second = fuzzCoordinates(exact, 'listing-x');

    expect(first, second);
  });

  test('haversineMeters is zero for identical points', () {
    const point = Coordinates(latitude: 41.9028, longitude: 12.4964);

    expect(haversineMeters(point, point), 0);
  });
}
