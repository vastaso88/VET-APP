import 'package:shared_preferences/shared_preferences.dart';

import '../domain/account_consent_models.dart';
import 'account_consents_remote_data_source.dart';

/// The Terms and the Privacy Policy accepted while signing up.
///
/// They are sent ONE AFTER THE OTHER: the server keeps the consents of an
/// account in one row, and two calls at the same time overwrote each other
/// (only one survived, and the app asked again at the next start). A call that
/// fails is retried once; one that still fails is kept on the phone and sent
/// again at the next start ([submitPending]) without blocking the sign-up.
class SignUpConsents {
  const SignUpConsents._();

  static const _pendingKey = 'vet_app.pending_signup_consents';

  static const keys = [
    AccountConsentKeys.termsOfService,
    AccountConsentKeys.privacyPolicy,
  ];

  /// Sends [pending] (all [keys] by default), in order. Returns the keys that
  /// could not be saved; they are also kept for the next start.
  static Future<List<String>> send(
    AccountConsentsRemoteDataSource source, {
    List<String> pending = keys,
  }) async {
    final failed = <String>[];
    for (final key in pending) {
      var result = await source.setConsent(consentKey: key, granted: true);
      if (result.isFailure) {
        result = await source.setConsent(consentKey: key, granted: true);
      }
      if (result.isFailure) failed.add(key);
    }
    await _store(failed);
    return failed;
  }

  /// Sends what a failed sign-up left on the phone, if anything.
  static Future<void> submitPending(AccountConsentsRemoteDataSource source) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final pending = (preferences.getStringList(_pendingKey) ?? const <String>[])
          .where(keys.contains)
          .toList();
      if (pending.isEmpty) return;
      await send(source, pending: pending);
    } catch (_) {}
  }

  /// Sign-out: nothing of this account stays.
  static Future<void> clear() => _store(const []);

  static Future<void> _store(List<String> pending) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (pending.isEmpty) {
        await preferences.remove(_pendingKey);
      } else {
        await preferences.setStringList(_pendingKey, pending);
      }
    } catch (_) {}
  }
}
