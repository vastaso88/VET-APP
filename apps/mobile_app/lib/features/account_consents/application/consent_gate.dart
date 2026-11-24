import 'dart:async';

import 'package:flutter/material.dart';

import '../data/account_consents_remote_data_source.dart';
import '../data/signup_consents.dart';
import '../domain/account_consent_models.dart';
import '../presentation/pages/consent_gate_page.dart';
import 'chat_notice.dart';

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
  final current = snapshot.catalog[key]?.version;
  // A text the server does not know cannot be accepted there: asking for it would keep
  // everybody out (the testers' builds 42 and 43 did, with an older server).
  if (current == null) return false;
  final decision = snapshot.decisions[key];
  return decision == null || !decision.granted || decision.version != current;
}

bool mandatoryConsentsMissing(AccountConsentsSnapshot snapshot) =>
    missingMandatoryKeys(snapshot).isNotEmpty;

/// After a sign-in (and when the app comes back): whatever mandatory text is not
/// accepted at the current version (Terms, Privacy Policy) is asked for. The
/// acknowledgement that Quokka does not handle emergencies is NOT asked here: it belongs
/// to the chat (see ChatNotice). True when the owner accepted everything that was asked:
/// the caller reloads, because what was fetched before was refused with
/// `consent_required`. A failure to read the state, or an owner who left or declined,
/// returns false.
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
  if (snapshot.catalog.containsKey(AccountConsentKeys.emergencyNotice)) {
    // Accepted in the chat while the server did not know it, or was out of reach.
    unawaited(ChatNotice.submitPending(source));
  }
  if (!mandatoryConsentsMissing(snapshot)) return false;
  final accepted = await Navigator.of(context, rootNavigator: true).push<bool>(
    MaterialPageRoute<bool>(
      fullscreenDialog: true,
      builder: (_) => ConsentGatePage(
        dataSource: source,
        catalogVersions: {
          for (final key in AccountConsentKeys.mandatory)
            if (snapshot.catalog[key] != null) key: snapshot.catalog[key]!.version,
        },
      ),
    ),
  );
  return accepted == true;
}
