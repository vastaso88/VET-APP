import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/types/result.dart';
import '../../auth/data/legal_texts_remote_data_source.dart';
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
    Map<String, String>? shownVersions,
    Future<Map<String, String>?> Function()? readCatalogVersions,
  }) async {
    // The version of the text the owner could open while signing up: the public catalog's,
    // else this build's own. Kept with the key if it cannot be sent now, and sent again as it was.
    final shown = shownVersions ??
        await (readCatalogVersions ?? LegalTextsRemoteDataSource().fetchVersions)();
    final failed = <String>[];
    final kept = <String>[];
    for (final key in pending) {
      final version = AccountConsentKeys.shownVersionIn(shown, key);
      var result = await source.setConsent(consentKey: key, granted: true, shownVersion: version);
      if (result.isFailure && !_isMismatch(result)) {
        result = await source.setConsent(consentKey: key, granted: true, shownVersion: version);
      }
      // A refused text (the catalog moved on) is not kept: the gate asks again with the new one.
      if (result.isFailure && !_isMismatch(result)) {
        failed.add(key);
        kept.add('$key$_separator${version ?? ''}');
      }
    }
    await _store(kept);
    return failed;
  }

  static const _separator = '|';

  static bool _isMismatch(Result<AccountConsentsSnapshot> result) =>
      result.fold(onSuccess: (_) => false, onFailure: (e) => e.code == kConsentVersionMismatchCode);

  /// Sends what a failed sign-up left on the phone, if anything, with the version it showed then.
  static Future<void> submitPending(AccountConsentsRemoteDataSource source) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final stored = preferences.getStringList(_pendingKey) ?? const <String>[];
      final keysToSend = <String>[];
      final versions = <String, String>{};
      for (final entry in stored) {
        final parts = entry.split(_separator);
        if (!keys.contains(parts.first)) continue;
        keysToSend.add(parts.first);
        if (parts.length > 1 && parts[1].isNotEmpty) versions[parts.first] = parts[1];
      }
      if (keysToSend.isEmpty) return;
      await send(source, pending: keysToSend, shownVersions: versions);
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
