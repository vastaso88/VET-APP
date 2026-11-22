import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// What the last run left behind so the next launch can skip the full splash:
/// whether the account had access (the subscription gate's last answer). The
/// open tab is no longer saved: every launch opens the Home. Only trusted for the same owner and for a few days;
/// the real gate still runs in the background and corrects it.
///
/// Also keeps the pages that were open inside the tabs and unsent drafts, so a
/// launch after Android killed the app can put the owner back where they were
/// (see route_restoration.dart).
class WarmStartStore {
  const WarmStartStore();

  /// Written by older builds on every tab change; never written or read now,
  /// only removed at sign-out so it does not linger.
  static const _legacyTabKey = 'vet_app.warm_start.tab';
  static const _ownerKey = 'vet_app.warm_start.access_owner';
  static const _atKey = 'vet_app.warm_start.access_at';
  static const _stackKey = 'vet_app.warm_start.route_stack';

  /// Unsent text of the page that was open (chat message...), keyed by page.
  static const draftPrefix = 'vet_app.draft.';

  /// How long a cached "has access" answer is believed.
  static const accessTtl = Duration(days: 3);

  /// Remembers the gate's answer: [hasAccess] true stores the owner and time,
  /// false forgets it so the next launch goes through the full gate.
  Future<void> saveAccess(String ownerId, {required bool hasAccess, DateTime? now}) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (hasAccess) {
        await preferences.setString(_ownerKey, ownerId);
        await preferences.setInt(_atKey, (now ?? DateTime.now()).millisecondsSinceEpoch);
      } else {
        await preferences.remove(_ownerKey);
        await preferences.remove(_atKey);
      }
    } catch (_) {}
  }

  /// True when the full splash can be skipped: access was confirmed for
  /// [ownerId] within [accessTtl]. False when absent, another owner, too old
  /// or unreadable.
  Future<bool> hasRecentAccess(String ownerId, {DateTime? now}) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (preferences.getString(_ownerKey) != ownerId) return false;
      final savedAt = preferences.getInt(_atKey);
      if (savedAt == null) return false;
      final age = (now ?? DateTime.now())
          .difference(DateTime.fromMillisecondsSinceEpoch(savedAt));
      return !age.isNegative && age <= accessTtl;
    } catch (_) {
      return false;
    }
  }

  /// The pages open inside the tabs, bottom to top.
  Future<void> saveStack(List<Map<String, dynamic>> entries) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_stackKey, jsonEncode(entries));
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> loadStack() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_stackKey);
      if (raw == null || raw.isEmpty) return const [];
      return [
        for (final entry in jsonDecode(raw) as List<dynamic>)
          Map<String, dynamic>.from(entry as Map),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveDraft(String key, String text) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (text.isEmpty) {
        await preferences.remove('$draftPrefix$key');
      } else {
        await preferences.setString('$draftPrefix$key', text);
      }
    } catch (_) {}
  }

  Future<String?> loadDraft(String key) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      return preferences.getString('$draftPrefix$key');
    } catch (_) {
      return null;
    }
  }

  /// Sign-out: forgets the cached access, the open pages and drafts.
  Future<void> clear() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(_legacyTabKey);
      await preferences.remove(_ownerKey);
      await preferences.remove(_atKey);
      await preferences.remove(_stackKey);
      final drafts =
          preferences.getKeys().where((key) => key.startsWith(draftPrefix)).toList();
      for (final key in drafts) {
        await preferences.remove(key);
      }
    } catch (_) {}
  }
}
