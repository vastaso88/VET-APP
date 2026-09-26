import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/auth/auth.dart';
import 'auth_session_store.dart';

class PersistentAuthSessionStore implements AuthSessionStore {
  PersistentAuthSessionStore({
    SharedPreferences? preferences,
  }) : _preferences = preferences;

  static const _storageKey = 'vet_app.auth_context';

  SharedPreferences? _preferences;

  AuthContext _context = const AuthContext();

  Future<SharedPreferences> _preferencesInstance() async {
    final preferences = _preferences;
    if (preferences != null) {
      return preferences;
    }

    final created = await SharedPreferences.getInstance();
    _preferences = created;
    return created;
  }

  @override
  Stream<AuthContext> watch() => const Stream<AuthContext>.empty();

  @override
  AuthContext read() => _context;

  @override
  Future<AuthContext> restore() async {
    final preferences = await _preferencesInstance();
    final raw = preferences.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      _context = const AuthContext();
      return _context;
    }

    try {
      final payload = jsonDecode(raw);
      if (payload is! Map<String, dynamic>) {
        _context = const AuthContext();
        return _context;
      }

      final userMap = payload['user'];
      final sessionMap = payload['session'];
      if (userMap is! Map || sessionMap is! Map) {
        _context = const AuthContext();
        return _context;
      }

      final restored = AuthContext(
        user: AppUser.fromMap(Map<String, dynamic>.from(userMap)),
        session: AppSession.fromMap(Map<String, dynamic>.from(sessionMap)),
        onboardingCompleted: payload['onboarding_completed'] as bool? ?? false,
        rememberMe: payload['remember_me'] as bool? ?? true,
      );

      if (!restored.rememberMe) {
        // "Resta connesso" was off at login: `restore()` is the app's cold-
        // start entry point, so a non-remembered session must not survive
        // it. We only drop the local copy here (no remote sign-out call) —
        // this store has no dependency on the remote auth client, and the
        // Supabase-backed path already keeps its own token store separate
        // from this one.
        await preferences.remove(_storageKey);
        _context = const AuthContext();
        return _context;
      }

      _context = restored;
    } catch (_) {
      _context = const AuthContext();
    }

    return _context;
  }

  @override
  Future<void> write(AuthContext context) async {
    _context = context;
    final preferences = await _preferencesInstance();

    if (context.user == null || context.session == null) {
      await preferences.remove(_storageKey);
      return;
    }

    final payload = <String, dynamic>{
      'user': context.user!.toMap(),
      'session': context.session!.toMap(),
      'onboarding_completed': context.onboardingCompleted,
      'remember_me': context.rememberMe,
    };
    await preferences.setString(_storageKey, jsonEncode(payload));
  }

  @override
  Future<void> clear() async {
    _context = const AuthContext();
    final preferences = await _preferencesInstance();
    await preferences.remove(_storageKey);
  }
}
