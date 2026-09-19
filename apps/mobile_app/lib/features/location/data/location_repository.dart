import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../shared/config/app_runtime_config_loader.dart';
import '../domain/coordinates.dart';

/// Syncs [UserLocationPreference] with the backend `user_locations` table
/// (one row per owner, flat lat/lng columns — see
/// scripts/setup/supabase_schema.sql). LocationPreferenceStore is the fast
/// local cache; this repository is the cross-device source of truth,
/// following the same optional-client, best-effort pattern as
/// RemindersRepository.
class LocationRepository {
  LocationRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  Future<UserLocationPreference?> loadRemote(String ownerId) async {
    final client = _resolveClient();
    if (client == null) {
      return null;
    }

    try {
      final response = await client
          .from('user_locations')
          .select('*')
          .eq('owner_id', ownerId)
          .limit(1)
          .maybeSingle();
      if (response == null) {
        return null;
      }
      return _parseRow(response);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveRemote(String ownerId, UserLocationPreference preference) async {
    final client = _resolveClient();
    if (client == null) {
      return;
    }

    try {
      await client.from('user_locations').upsert({
        'owner_id': ownerId,
        'mode': preference.mode == LocationMode.homeResidence
            ? 'home_residence'
            : 'current_position',
        'home_latitude': preference.home?.latitude,
        'home_longitude': preference.home?.longitude,
        'home_label': preference.homeLabel,
        'current_latitude': preference.current?.latitude,
        'current_longitude': preference.current?.longitude,
        'current_label': preference.currentLabel,
        'current_source': _sourceToString(preference.currentSource),
        'current_captured_at': preference.currentCapturedAt?.toIso8601String(),
      });
    } catch (_) {
      // Best-effort: the local cache already has this value regardless.
    }
  }

  /// Defensive parsing: any row that doesn't at least resolve means the
  /// caller falls back to the local cache rather than risking a crash.
  UserLocationPreference? _parseRow(Map<String, dynamic> row) {
    final homeLatitude = (row['home_latitude'] as num?)?.toDouble();
    final homeLongitude = (row['home_longitude'] as num?)?.toDouble();
    final currentLatitude = (row['current_latitude'] as num?)?.toDouble();
    final currentLongitude = (row['current_longitude'] as num?)?.toDouble();

    return UserLocationPreference(
      mode: row['mode'] == 'home_residence' ? LocationMode.homeResidence : LocationMode.currentPosition,
      home: homeLatitude != null && homeLongitude != null
          ? Coordinates(latitude: homeLatitude, longitude: homeLongitude)
          : null,
      homeLabel: row['home_label'] as String?,
      current: currentLatitude != null && currentLongitude != null
          ? Coordinates(latitude: currentLatitude, longitude: currentLongitude)
          : null,
      currentLabel: row['current_label'] as String?,
      currentSource: row['current_source'] == 'device_gps'
          ? LocationSource.deviceGps
          : row['current_source'] == 'manual'
              ? LocationSource.manual
              : null,
      currentCapturedAt: DateTime.tryParse((row['current_captured_at'] ?? '').toString()),
    );
  }

  String? _sourceToString(LocationSource? source) {
    switch (source) {
      case LocationSource.deviceGps:
        return 'device_gps';
      case LocationSource.manual:
        return 'manual';
      case null:
        return null;
    }
  }

  SupabaseClient? _resolveClient() {
    if (_client != null) {
      return _client;
    }

    final config = const AppRuntimeConfigLoader().load();
    if (!config.hasSupabaseCredentials) {
      return null;
    }

    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }
}
