import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/notification_plan.dart';

/// Per-category notification switches from Impostazioni, kept on this
/// phone (shared_preferences) — same pattern as LayoutSettingsStore.
class NotificationPreferencesStore extends ChangeNotifier {
  NotificationPreferencesStore._();

  static final NotificationPreferencesStore instance = NotificationPreferencesStore._();

  static const _storageKey = 'vet_app.notification_preferences';

  NotificationPreferences _preferences = const NotificationPreferences();
  NotificationPreferences get preferences => _preferences;

  Future<void>? _loading;

  Future<void> ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final storage = await SharedPreferences.getInstance();
      final raw = storage.getString(_storageKey);
      if (raw == null || raw.isEmpty) return;
      final payload = jsonDecode(raw) as Map<String, dynamic>;
      _preferences = NotificationPreferences(
        reminders: payload['reminders'] as bool? ?? true,
        medicines: payload['medicines'] as bool? ?? true,
        birthdays: payload['birthdays'] as bool? ?? true,
      );
      notifyListeners();
    } catch (_) {
      // Keep defaults — a corrupt or missing preference isn't fatal.
    }
  }

  Future<void> update(NotificationPreferences preferences) async {
    _preferences = preferences;
    notifyListeners();

    try {
      final storage = await SharedPreferences.getInstance();
      await storage.setString(
        _storageKey,
        jsonEncode({
          'reminders': preferences.reminders,
          'medicines': preferences.medicines,
          'birthdays': preferences.birthdays,
        }),
      );
    } catch (_) {
      // Best-effort: the in-memory value already applies for this session.
    }
  }
}
