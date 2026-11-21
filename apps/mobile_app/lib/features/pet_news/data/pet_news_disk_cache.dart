import 'package:shared_preferences/shared_preferences.dart';

/// The last good answer of GET /news kept on the phone, so a failed or slow
/// request (the server reads the magazines' feeds on demand every couple of
/// hours, and the first request after that can be slow) shows the last news
/// instead of "non disponibile". Public headlines only: nothing about the owner.
/// Emptied when the owner signs out, like every local store.
class PetNewsDiskCache {
  const PetNewsDiskCache();

  static const _bodyKey = 'vet_app.pet_news.last_body';
  static const _atKey = 'vet_app.pet_news.last_at';

  /// How old a kept copy may be and still be shown: headlines older than this
  /// are worse than the honest "unavailable" with its retry button.
  static const maxAge = Duration(days: 14);

  Future<void> save(String body, DateTime at) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_bodyKey, body);
      await preferences.setInt(_atKey, at.millisecondsSinceEpoch);
    } catch (_) {}
  }

  /// The kept answer and when it was saved, or null when there is none (or it is too old).
  Future<({String body, DateTime savedAt})?> load({DateTime? now}) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final body = preferences.getString(_bodyKey);
      final at = preferences.getInt(_atKey);
      if (body == null || body.isEmpty || at == null) return null;
      final savedAt = DateTime.fromMillisecondsSinceEpoch(at);
      final age = (now ?? DateTime.now()).difference(savedAt);
      if (age.isNegative || age > maxAge) return null;
      return (body: body, savedAt: savedAt);
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(_bodyKey);
      await preferences.remove(_atKey);
    } catch (_) {}
  }
}
