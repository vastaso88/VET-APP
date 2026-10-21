import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// What the last run left behind so the next launch can skip the full splash:
/// the tab that was open and whether the account had access (the subscription
/// gate's last answer). Only trusted for the same owner and for a few days;
/// the real gate still runs in the background and corrects it.
///
/// Also keeps the pages that were open inside the tabs and unsent drafts, so a
/// launch after Android killed the app can put the owner back where they were
/// (see route_restoration.dart).
class WarmStartStore {
  const WarmStartStore();

  static const _tabKey = 'vet_app.warm_start.tab';
  static const _ownerKey = 'vet_app.warm_start.access_owner';
  static const _atKey = 'vet_app.warm_start.access_at';
  static const _stackKey = 'vet_app.warm_start.route_stack';

  /// Unsent text of the page that was open (chat message...), keyed by page.
  static const draftPrefix = 'vet_app.draft.';

  /// How long a cached "has access" answer is believed.
  static const accessTtl = Duration(days: 3);

  Future<void> saveTab(int index) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setInt(_tabKey, index);
    } catch (_) {}
  }

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

  /// The tab to open straight away, or null when the full splash must run
  /// (no cached access for [ownerId], too old, or nothing readable).
  Future<int?> warmTab(String ownerId, {DateTime? now}) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (preferences.getString(_ownerKey) != ownerId) return null;
      final savedAt = preferences.getInt(_atKey);
      if (savedAt == null) return null;
      final age = (now ?? DateTime.now())
          .difference(DateTime.fromMillisecondsSinceEpoch(savedAt));
      if (age.isNegative || age > accessTtl) return null;
      final tab = preferences.getInt(_tabKey) ?? 0;
      return tab.clamp(0, 3);
    } catch (_) {
      return null;
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

  /// Sign-out: forgets the tab, the cached access, the open pages and drafts.
  Future<void> clear() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(_tabKey);
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
