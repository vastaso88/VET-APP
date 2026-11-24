import 'package:flutter/material.dart';

import '../data/account_consents_remote_data_source.dart';
import '../data/signup_consents.dart';
import '../domain/account_consent_models.dart';
import '../presentation/pages/consent_gate_page.dart';
import '../presentation/pages/emergency_notice_gate_page.dart';

/// The mandatory keys not accepted at the version the backend serves now: never
/// accepted, declined, or accepted at an older version. The backend answers
/// `consent_required` to the protected routes in the same case.
List<String> missingMandatoryKeys(AccountConsentsSnapshot snapshot) {
  return [
    for (final key in AccountConsentKeys.mandatory)
      if (_isMissing(snapshot, key)) key,
  ];
}

bool _isMissing(AccountConsentsSnapshot snapshot, String key) {
  final decision = snapshot.decisions[key];
  final current = snapshot.catalog[key]?.version;
  return decision == null || !decision.granted || current == null || decision.version != current;
}

bool mandatoryConsentsMissing(AccountConsentsSnapshot snapshot) =>
    missingMandatoryKeys(snapshot).isNotEmpty;

/// After a sign-in (and when the app comes back): whatever mandatory text is not
/// accepted at the current version is asked for, one page per step: first the Terms
/// and the Privacy Policy, then the acknowledgement that Quokka does not handle
/// emergencies on a page of its own (docs/compliance/22 §5). True when the owner
/// accepted everything that was asked: the caller reloads, because what was fetched
/// before was refused with `consent_required`. A failure to read the state, or an
/// owner who left or declined, returns false.
Future<bool> ensureMandatoryConsents(
  BuildContext context, {
  AccountConsentsRemoteDataSource? dataSource,
}) async {
  final source = dataSource ?? HttpAccountConsentsRemoteDataSource();
  // What a sign-up could not save is sent now, before asking the owner again.
  await SignUpConsents.submitPending(source);
  if (!context.mounted) return false;
  final result = await source.fetch();
  if (!context.mounted) return false;
  final snapshot = result.fold(onSuccess: (value) => value, onFailure: (_) => null);
  if (snapshot == null) return false;
  final missing = missingMandatoryKeys(snapshot);
  if (missing.isEmpty) return false;

  final navigator = Navigator.of(context, rootNavigator: true);
  if (missing.contains(AccountConsentKeys.termsOfService) ||
      missing.contains(AccountConsentKeys.privacyPolicy)) {
    final accepted = await navigator.push<bool>(
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (_) => ConsentGatePage(dataSource: source),
      ),
    );
    if (accepted != true || !context.mounted) return false;
  }
  if (missing.contains(AccountConsentKeys.emergencyNotice)) {
    final accepted = await navigator.push<bool>(
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (_) => EmergencyNoticeGatePage(dataSource: source),
      ),
    );
    if (accepted != true) return false;
  }
  return true;
}
