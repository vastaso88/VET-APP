import 'package:shared_preferences/shared_preferences.dart';

/// Remembers the "Resta connesso" choice made at sign-in.
///
/// The Supabase SDK always persists its session on disk; it has no runtime
/// switch for that. So the choice is honoured at the next launch instead:
/// when the owner asked not to stay signed in, `bootstrap.dart` signs the
/// stored session out locally before the first screen appears (security
/// audit 2026-10-26, finding app-A2). Defaults to true (stay signed in).
class RememberMeStore {
  const RememberMeStore._();

  static const _storageKey = 'vet_app.remember_me';

  static Future<bool> read() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      return preferences.getBool(_storageKey) ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> write(bool rememberMe) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_storageKey, rememberMe);
    } catch (_) {
      // Best-effort: worst case the session is kept, the previous behaviour.
    }
  }
}
