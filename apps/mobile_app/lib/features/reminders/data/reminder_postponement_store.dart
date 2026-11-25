import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/reminder_completion.dart';
import 'reminders_repository.dart';

/// "Rimanda": until when each postponed reminder is on hold, kept on this phone
/// (private storage) so it outlives the app and a reboot. The scheduler turns
/// each one into a notification, the prompter asks again from that moment.
/// Emptied at sign-out (bootstrap.dart).
///
/// Per occurrence ([completedRecordId]): the answer to one due date does not
/// silence the next, and moving the reminder to another day drops it.
class ReminderPostponementStore extends ChangeNotifier {
  ReminderPostponementStore._();

  static final ReminderPostponementStore instance = ReminderPostponementStore._();

  @visibleForTesting
  static const storageKey = 'vet_app.reminder_postponements';

  Future<DateTime?> load(ReminderEntry reminder) async =>
      _read(await _preferences())[completedRecordId(reminder)];

  /// The postponements of [reminders]' current occurrences, by reminder id.
  Future<Map<String, DateTime>> forReminders(Iterable<ReminderEntry> reminders) async {
    final stored = _read(await _preferences());
    if (stored.isEmpty) return const {};
    final byId = <String, DateTime>{};
    for (final reminder in reminders) {
      final until = stored[completedRecordId(reminder)];
      if (until != null) byId[reminder.id] = until;
    }
    return byId;
  }

  /// Puts [reminder]'s current occurrence on hold until [until]. Postponements
  /// too old to count any more (see [kAutoPromptWindowDays]) go away on the way.
  Future<void> save(ReminderEntry reminder, DateTime until, {required DateTime now}) =>
      _change((stored) {
        stored.removeWhere((_, at) => now.difference(at).inDays > kAutoPromptWindowDays + 1);
        stored[completedRecordId(reminder)] = until;
      });

  Future<void> forget(ReminderEntry reminder) =>
      _change((stored) => stored.remove(completedRecordId(reminder)));

  /// Sign-out.
  Future<void> clear() => _change((stored) => stored.clear());

  Future<void> _change(void Function(Map<String, DateTime> stored) change) async {
    final preferences = await _preferences();
    if (preferences == null) return;
    final before = _read(preferences);
    final after = {...before};
    change(after);
    if (mapEquals(before, after)) return;
    try {
      if (after.isEmpty) {
        await preferences.remove(storageKey);
      } else {
        await preferences.setString(
          storageKey,
          jsonEncode({for (final entry in after.entries) entry.key: entry.value.toIso8601String()}),
        );
      }
    } catch (_) {
      // Best-effort, like the other small stores on the phone.
    }
    notifyListeners();
  }

  static Future<SharedPreferences?> _preferences() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  static Map<String, DateTime> _read(SharedPreferences? preferences) {
    try {
      final raw = preferences?.getString(storageKey);
      if (raw == null || raw.isEmpty) return const {};
      final byOccurrence = <String, DateTime>{};
      for (final entry in (jsonDecode(raw) as Map<String, dynamic>).entries) {
        final until = DateTime.tryParse(entry.value.toString());
        if (until != null) byOccurrence[entry.key] = until;
      }
      return byOccurrence;
    } catch (_) {
      // Unreadable: nothing is postponed.
      return const {};
    }
  }
}
