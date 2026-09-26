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
      }),
    });

    await LocationPreferenceStore.instance.ensureLoaded();
    final preference = LocationPreferenceStore.instance.preference;

    expect(preference.mode, LocationMode.homeResidence);
    expect(preference.home, const Coordinates(latitude: 45.4642, longitude: 9.1900));
    expect(preference.homeLabel, 'Milano');
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
