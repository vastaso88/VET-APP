import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/coordinates.dart';

/// Session-lifetime, persisted (shared_preferences) store for the device's
/// local copy of the user's location preference. Same pattern as
/// LayoutSettingsStore — a [ChangeNotifier] singleton so any screen reacts
/// live when the location changes. The backend `user_locations` table
/// (via LocationRepository) is the cross-device source of truth; this
/// store is the fast local cache / offline default.
class LocationPreferenceStore extends ChangeNotifier {
  LocationPreferenceStore._();

  static final LocationPreferenceStore instance = LocationPreferenceStore._();

  static const _storageKey = 'vet_app.location_preference';

  UserLocationPreference _preference = const UserLocationPreference();
  UserLocationPreference get preference => _preference;

  bool _loaded = false;
  Future<void>? _loadingFuture;

  /// Safe to call concurrently from multiple screens: callers that arrive
  /// while a load is already in flight await that same future instead of
  /// each racing SharedPreferences and seeing `_loaded` flip early.
  Future<void> ensureLoaded() {
    if (_loaded) return Future.value();
    return _loadingFuture ??= _load();
  }

  Future<void> _load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_storageKey);
      if (raw == null || raw.isEmpty) {
        return;
      }

      final payload = jsonDecode(raw) as Map<String, dynamic>;
      _preference = UserLocationPreference(
        mode: payload['mode'] == 'home_residence'
            ? LocationMode.homeResidence
            : LocationMode.currentPosition,
        home: _coordinatesFromJson(payload['home'] as Map<String, dynamic>?),
        homeLabel: payload['home_label'] as String?,
        current: _coordinatesFromJson(payload['current'] as Map<String, dynamic>?),
        currentLabel: payload['current_label'] as String?,
        currentSource: payload['current_source'] == 'device_gps'
            ? LocationSource.deviceGps
            : payload['current_source'] == 'manual'
                ? LocationSource.manual
                : null,
        currentCapturedAt: DateTime.tryParse((payload['current_captured_at'] ?? '').toString()),
      );
      notifyListeners();
    } catch (_) {
      // Keep defaults — a corrupt or missing preference isn't fatal.
    } finally {
      _loaded = true;
    }
  }

  Future<void> update(UserLocationPreference preference) async {
    _preference = preference;
    notifyListeners();

    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_storageKey, jsonEncode(_toJson(preference)));
    } catch (_) {
      // Best-effort: the in-memory value above already applied for this
      // session even if writing the preference itself fails.
    }
  }

  static Coordinates? _coordinatesFromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final latitude = (json['latitude'] as num?)?.toDouble();
    final longitude = (json['longitude'] as num?)?.toDouble();
    if (latitude == null || longitude == null) return null;
    return Coordinates(latitude: latitude, longitude: longitude);
  }

  static Map<String, dynamic> _toJson(UserLocationPreference preference) {
    return {
      'mode': preference.mode == LocationMode.homeResidence ? 'home_residence' : 'current_position',
      if (preference.home != null)
        'home': {'latitude': preference.home!.latitude, 'longitude': preference.home!.longitude},
      'home_label': preference.homeLabel,
      if (preference.current != null)
        'current': {
          'latitude': preference.current!.latitude,
          'longitude': preference.current!.longitude,
        },
      'current_label': preference.currentLabel,
      'current_source': preference.currentSource == LocationSource.deviceGps
          ? 'device_gps'
          : preference.currentSource == LocationSource.manual
              ? 'manual'
              : null,
      'current_captured_at': preference.currentCapturedAt?.toIso8601String(),
    };
  }
}
