import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum WeekStartDay { monday, sunday }

enum ListDensity { comfortable, compact }

class LayoutSettings {
  const LayoutSettings({
    this.weeksShown = 2,
    this.weekStartDay = WeekStartDay.monday,
    this.listDensity = ListDensity.comfortable,
  });

  /// How many weeks the Home agenda's week-strip shows at once, 1-4.
  final int weeksShown;
  final WeekStartDay weekStartDay;
  final ListDensity listDensity;

  LayoutSettings copyWith({
    int? weeksShown,
    WeekStartDay? weekStartDay,
    ListDensity? listDensity,
  }) {
    return LayoutSettings(
      weeksShown: weeksShown ?? this.weeksShown,
      weekStartDay: weekStartDay ?? this.weekStartDay,
      listDensity: listDensity ?? this.listDensity,
    );
  }
}

/// Session-lifetime, persisted (shared_preferences) store for Home layout
/// preferences. A [ChangeNotifier] singleton — same pattern as
/// ChatDemoStore/PetDemoStore — so Home reacts live when the user changes a
/// setting, instead of requiring a full app restart to take effect.
class LayoutSettingsStore extends ChangeNotifier {
  LayoutSettingsStore._();

  static final LayoutSettingsStore instance = LayoutSettingsStore._();

  static const _storageKey = 'vet_app.layout_settings';

  LayoutSettings _settings = const LayoutSettings();
  LayoutSettings get settings => _settings;

  bool _loaded = false;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;

    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_storageKey);
      if (raw == null || raw.isEmpty) {
        return;
      }

      final payload = jsonDecode(raw) as Map<String, dynamic>;
      _settings = LayoutSettings(
        weeksShown: ((payload['weeks_shown'] as num?)?.toInt() ?? 2).clamp(1, 4),
        weekStartDay:
            payload['week_start'] == 'sunday' ? WeekStartDay.sunday : WeekStartDay.monday,
        listDensity:
            payload['density'] == 'compact' ? ListDensity.compact : ListDensity.comfortable,
      );
      notifyListeners();
    } catch (_) {
      // Keep defaults — a corrupt or missing preference isn't fatal.
    }
  }

  Future<void> update(LayoutSettings settings) async {
    _settings = settings;
    notifyListeners();

    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        _storageKey,
        jsonEncode({
          'weeks_shown': settings.weeksShown,
          'week_start': settings.weekStartDay == WeekStartDay.sunday ? 'sunday' : 'monday',
          'density': settings.listDensity == ListDensity.compact ? 'compact' : 'comfortable',
        }),
      );
    } catch (_) {
      // Best-effort: the in-memory value above already applied for this
      // session even if writing the preference itself fails.
    }
  }
}
