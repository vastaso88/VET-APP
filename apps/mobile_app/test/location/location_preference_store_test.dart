import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vet_app_mobile/features/location/data/location_preference_store.dart';
import 'package:vet_app_mobile/features/location/domain/coordinates.dart';

/// LocationPreferenceStore is a hard singleton (private constructor, same
/// pattern as LayoutSettingsStore), so these two tests intentionally run
/// as one sequence within a single isolate: the first exercises the load
/// path (`ensureLoaded` only ever reads from disk once), the second
/// exercises `update` afterwards.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads a previously saved preference from shared_preferences', () async {
    SharedPreferences.setMockInitialValues({
      'vet_app.location_preference': jsonEncode({
        'mode': 'home_residence',
        'home': {'latitude': 45.4642, 'longitude': 9.1900},
        'home_label': 'Milano',
        'home_country_code': 'IT',
        'home_city': 'Milano',
        'home_saved_at': '2026-11-21T10:00:00Z',
      }),
    });

    await LocationPreferenceStore.instance.ensureLoaded();
    final preference = LocationPreferenceStore.instance.preference;

    expect(preference.mode, LocationMode.homeResidence);
    expect(preference.home, const Coordinates(latitude: 45.4642, longitude: 9.1900));
    expect(preference.homeLabel, 'Milano');
    expect(preference.homeCountryCode, 'IT');
    expect(preference.homeCity, 'Milano');
    expect(preference.homeSavedAt, DateTime.utc(2026, 11, 21, 10));
  });

  test('changing residence clears stale country, GPS updates keep residence', () {
    const before = UserLocationPreference(home: Coordinates(latitude: 45, longitude: 9), homeCountryCode: 'IT', homeCity: 'Example city');
    expect(before.copyWith(home: const Coordinates(latitude: 48, longitude: 2)).homeCountryCode, isNull);
    expect(before.copyWith(current: const Coordinates(latitude: 48, longitude: 2)).homeCountryCode, 'IT');
  });

  test('update persists the new preference to shared_preferences', () async {
    await LocationPreferenceStore.instance.update(
      const UserLocationPreference(
        current: Coordinates(latitude: 41.9028, longitude: 12.4964),
        currentLabel: 'Roma',
        currentSource: LocationSource.deviceGps,
      ),
    );

    expect(LocationPreferenceStore.instance.preference.currentLabel, 'Roma');

    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString('vet_app.location_preference');
    final decoded = jsonDecode(raw!) as Map<String, dynamic>;
    expect(decoded['current_label'], 'Roma');
    expect(decoded['current_source'], 'device_gps');
  });
}
