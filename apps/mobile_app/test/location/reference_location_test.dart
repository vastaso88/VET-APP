import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/location/domain/coordinates.dart';
import 'package:vet_app_mobile/features/location/presentation/reference_location.dart';

void main() {
  const fallback = Coordinates(latitude: 0, longitude: 0);
  const home = Coordinates(latitude: 45.4642, longitude: 9.1900);
  const current = Coordinates(latitude: 41.9028, longitude: 12.4964);

  test('mode homeResidence prefers home even when current is also set', () {
    const preference = UserLocationPreference(
      mode: LocationMode.homeResidence,
      home: home,
      current: current,
    );

    expect(resolveReferenceLocation(preference, fallback), home);
  });

  test('mode currentPosition prefers current even when home is also set', () {
    const preference = UserLocationPreference(
      mode: LocationMode.currentPosition,
      home: home,
      current: current,
    );

    expect(resolveReferenceLocation(preference, fallback), current);
  });

  test('falls back to the other field when the mode-selected one is missing', () {
    const preference = UserLocationPreference(mode: LocationMode.homeResidence, current: current);

    expect(resolveReferenceLocation(preference, fallback), current);
  });

  test('falls back to the provided fallback when nothing is set', () {
    const preference = UserLocationPreference();

    expect(resolveReferenceLocation(preference, fallback), fallback);
  });
}
