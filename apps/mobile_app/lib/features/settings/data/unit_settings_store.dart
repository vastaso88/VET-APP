import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/unit_system.dart';

/// The owner's measurement system, saved on the phone. A [ChangeNotifier]
/// singleton (same pattern as LayoutSettingsStore) so screens that show a
/// distance, weight, temperature or volume can rebuild when it changes.
///
/// Reads are synchronous: [system] is the default until [ensureLoaded] has
/// run (it is called when the app starts and by the settings page).
class UnitSettingsStore extends ChangeNotifier {
  UnitSettingsStore._();

  static final UnitSettingsStore instance = UnitSettingsStore._();

  static const _storageKey = 'vet_app.unit_system';

  UnitSystem _system = defaultUnitsForLocale(null);
  UnitSystem get system => _system;

  bool _loaded = false;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final preferences = await SharedPreferences.getInstance();
      final stored = UnitSystem.fromName(preferences.getString(_storageKey));
      if (stored != null && stored != _system) {
        _system = stored;
        notifyListeners();
      }
    } catch (_) {
      // Keep the default: a missing preference isn't fatal.
    }
  }

  Future<void> setSystem(UnitSystem system) async {
    _loaded = true;
    if (system == _system) return;
    _system = system;
    notifyListeners();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_storageKey, system.name);
    } catch (_) {
      // Best-effort: the in-memory value already applies for this session.
    }
  }
}
