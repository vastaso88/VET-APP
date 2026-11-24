import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vet_app_mobile/features/account_consents/data/account_consents_remote_data_source.dart';
import 'package:vet_app_mobile/features/account_consents/data/signup_consents.dart';
import 'package:vet_app_mobile/features/account_consents/domain/account_consent_models.dart';
import 'package:vet_app_mobile/shared/errors/app_network_error.dart';
import 'package:vet_app_mobile/shared/types/result.dart';

const _terms = AccountConsentKeys.termsOfService;
const _privacy = AccountConsentKeys.privacyPolicy;

const _empty = AccountConsentsSnapshot(decisions: {}, catalog: {});

/// Records every call and whether another one was still running.
class _Backend implements AccountConsentsRemoteDataSource {
  _Backend({this.failures = const {}});

  /// Number of times each key still fails.
  final Map<String, int> failures;
  final List<String> calls = [];
  final List<String?> versions = [];

  /// A key whose acceptance is refused as a text that is not the current one.
  final Set<String> mismatch = {};
  int running = 0;
  bool overlapped = false;

  @override
  Future<Result<AccountConsentsSnapshot>> fetch() async => Result.success(_empty);

  @override
  Future<Result<AccountConsentsSnapshot>> setConsent({
    required String consentKey,
    required bool granted,
    String? shownVersion,
  }) async {
    running++;
    if (running > 1) overlapped = true;
    await Future<void>.delayed(const Duration(milliseconds: 5));
    running--;
    calls.add(consentKey);
    versions.add(shownVersion);
    if (mismatch.contains(consentKey)) {
      return Result.failure(const AppNetworkError(code: kConsentVersionMismatchCode));
    }
    final left = failures[consentKey] ?? 0;
    if (left > 0) {
      failures[consentKey] = left - 1;
      return Result.failure(const AppNetworkError(code: 'consent_http_500'));
    }
    return Result.success(_empty);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('both keys are sent, one after the other (never overlapping)', () async {
    final backend = _Backend();
    final failed = await SignUpConsents.send(backend);
    expect(failed, isEmpty);
    expect(backend.calls, [_terms, _privacy]);
    expect(backend.overlapped, isFalse);
  });

  test('a failed call is retried once and the sign-up goes on', () async {
    final backend = _Backend(failures: {_terms: 1});
    expect(await SignUpConsents.send(backend), isEmpty);
    expect(backend.calls, [_terms, _terms, _privacy]);
  });

  test('a key that fails twice is kept and sent again at the next start', () async {
    final backend = _Backend(failures: {_privacy: 2});
    expect(await SignUpConsents.send(backend), [_privacy]);
    expect(backend.calls, [_terms, _privacy, _privacy]);

    final later = _Backend();
    await SignUpConsents.submitPending(later);
    expect(later.calls, [_privacy], reason: 'only what is missing, not the Terms again');

    final again = _Backend();
    await SignUpConsents.submitPending(again);
    expect(again.calls, isEmpty, reason: 'sent once, then forgotten');
  });

  test('signing out forgets what was pending', () async {
    await SignUpConsents.send(_Backend(failures: {_terms: 2}));
    await SignUpConsents.clear();
    final later = _Backend();
    await SignUpConsents.submitPending(later);
    expect(later.calls, isEmpty);
  });

  test('the version sent is the catalogue version, else the build version', () async {
    final backend = _Backend();
    await SignUpConsents.send(backend, readCatalogVersions: () async => {_terms: 'v5'});
    expect(backend.versions, ['v5', AccountConsentKeys.shownVersions[_privacy]]);

    final offline = _Backend();
    await SignUpConsents.send(offline, readCatalogVersions: () async => null);
    expect(offline.versions, [
      AccountConsentKeys.shownVersions[_terms],
      AccountConsentKeys.shownVersions[_privacy],
    ]);
  });

  test('what is kept for later is sent with the version shown then, not the current one', () async {
    final first = _Backend(failures: {_terms: 2});
    await SignUpConsents.send(first, shownVersions: {_terms: 'v5', _privacy: 'v6'});

    final later = _Backend();
    await SignUpConsents.submitPending(later);
    expect(later.calls, [_terms]);
    expect(later.versions, ['v5']);
  });

  test('a refused text is not kept: the gate asks again with the new one', () async {
    final backend = _Backend()..mismatch.add(_terms);
    final failed = await SignUpConsents.send(backend, shownVersions: {_terms: 'v1'});
    expect(failed, isEmpty);

    final later = _Backend();
    await SignUpConsents.submitPending(later);
    expect(later.calls, isEmpty);
  });
}
