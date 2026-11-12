import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Last server answer for one owner's list (pets, reminders), kept on the
/// phone so the next launch - typically after Android dropped the app from
/// memory - shows data at once and refreshes it in the background.
///
/// Keyed by owner id (a different account never sees it) and wiped on sign-out
/// by [clearAll]. Every call is best-effort: a missing or unreadable cache is
/// just a cache miss.
class OwnerJsonCache {
  const OwnerJsonCache(this.name);

  final String name;

  static const _prefix = 'vet_app.cache.';

  String _key(String ownerId) => '$_prefix$name.$ownerId';

  Future<List<Map<String, dynamic>>?> read(String ownerId) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_key(ownerId));
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw) as List<dynamic>;
      return [for (final row in decoded) Map<String, dynamic>.from(row as Map)];
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String ownerId, List<Map<String, dynamic>> rows) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_key(ownerId), jsonEncode(rows));
    } catch (_) {
      // Best-effort: the live data in memory is what the screens use.
    }
  }

  /// Removes every owner's cached lists (sign-out).
  static Future<void> clearAll() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      for (final key in preferences.getKeys().where((key) => key.startsWith(_prefix)).toList()) {
        await preferences.remove(key);
      }
    } catch (_) {}
  }
}
