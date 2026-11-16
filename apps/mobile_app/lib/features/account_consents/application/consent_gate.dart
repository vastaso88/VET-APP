import 'package:flutter/material.dart';

import '../data/account_consents_remote_data_source.dart';
import '../domain/account_consent_models.dart';
import '../presentation/pages/consent_gate_page.dart';

/// True when the Terms of Service or the Privacy Policy are not accepted at the
/// version the backend serves now (never accepted, or accepted at an older
/// version). The backend answers `consent_required` to the protected routes in
/// the same case.
bool mandatoryConsentsMissing(AccountConsentsSnapshot snapshot) {
  for (final key in const [
    AccountConsentKeys.termsOfService,
    AccountConsentKeys.privacyPolicy,
  ]) {
    final decision = snapshot.decisions[key];
    final current = snapshot.catalog[key]?.version;
    if (decision == null || !decision.granted || current == null || decision.version != current) {
      return true;
    }
  }
  return false;
}

/// After a sign-in (and when the app comes back): if the Terms or the Privacy
/// Policy are not accepted at the current version, shows the blocking page that
/// asks for them. True when the page was shown and the owner accepted: the caller
/// reloads, because everything fetched before was refused with `consent_required`.
/// A failure to read the state, or an owner who left, returns false.
Future<bool> ensureMandatoryConsents(
  BuildContext context, {
  AccountConsentsRemoteDataSource? dataSource,
}) async {
  final source = dataSource ?? HttpAccountConsentsRemoteDataSource();
  final result = await source.fetch();
  if (!context.mounted) return false;
  final snapshot = result.fold(onSuccess: (value) => value, onFailure: (_) => null);
  if (snapshot == null || !mandatoryConsentsMissing(snapshot)) return false;

  final accepted = await Navigator.of(context, rootNavigator: true).push<bool>(
    MaterialPageRoute<bool>(
      fullscreenDialog: true,
      builder: (_) => ConsentGatePage(dataSource: source),
    ),
  );
  return accepted == true;
}
