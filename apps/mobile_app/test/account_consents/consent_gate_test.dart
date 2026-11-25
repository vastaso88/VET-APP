import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vet_app_mobile/features/account_consents/application/consent_gate.dart';
import 'package:vet_app_mobile/features/account_consents/data/account_consents_remote_data_source.dart';
import 'package:vet_app_mobile/features/account_consents/domain/account_consent_models.dart';
import 'package:vet_app_mobile/features/account_consents/presentation/pages/consent_gate_page.dart';
import 'package:vet_app_mobile/l10n/l10n.dart';
import 'package:vet_app_mobile/shared/errors/app_network_error.dart';
import 'package:vet_app_mobile/shared/types/result.dart';

const _terms = AccountConsentKeys.termsOfService;
const _privacy = AccountConsentKeys.privacyPolicy;
const _emergency = AccountConsentKeys.emergencyNotice;

ConsentDecision _decision(String version, {bool granted = true}) =>
    ConsentDecision(granted: granted, version: version, decidedAt: DateTime(2026, 11, 16));

AccountConsentsSnapshot _snapshot(Map<String, ConsentDecision> decisions) =>
    AccountConsentsSnapshot(
      decisions: decisions,
      catalog: const {
        _terms: ConsentCatalogEntry(version: 'v2', text: 'termini'),
        _privacy: ConsentCatalogEntry(version: 'v3', text: 'informativa'),
        _emergency: ConsentCatalogEntry(version: 'v1', text: 'urgenze'),
      },
    );

Map<String, ConsentDecision> get _all => {
      _terms: _decision('v2'),
      _privacy: _decision('v3'),
      _emergency: _decision('v1'),
    };

class _Backend implements AccountConsentsRemoteDataSource {
  _Backend(this.snapshot, {this.failSet = false});

  AccountConsentsSnapshot snapshot;
  final bool failSet;
  final List<String> set = [];

  /// What each acceptance declared, by key.
  final Map<String, String?> declared = {};

  /// The versions the server holds now; an acceptance for another one is refused (400
  /// `consent_version_mismatch`). Null: every version is accepted.
  Map<String, String>? serverVersions;

  @override
  Future<Result<AccountConsentsSnapshot>> fetch() async => Result.success(snapshot);

  @override
  Future<Result<AccountConsentsSnapshot>> setConsent({
    required String consentKey,
    required bool granted,
    String? shownVersion,
  }) async {
    if (failSet) return Result.failure(const AppNetworkError(code: 'consent_http_500'));
    final current = serverVersions;
    if (current != null && shownVersion != null && shownVersion != current[consentKey]) {
      return Result.failure(const AppNetworkError(code: kConsentVersionMismatchCode));
    }
    declared[consentKey] = shownVersion;
    set.add(consentKey);
    return Result.success(snapshot);
  }
}

Widget _app(Widget Function(BuildContext) home) {
  AppLocaleHolder.current = const Locale('it');
  return MaterialApp(
    locale: const Locale('it'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: Builder(builder: home),
  );
}

Widget _starter(AccountConsentsRemoteDataSource backend, void Function(bool?) onResult) {
  return _app(
    (context) => TextButton(
      onPressed: () async => onResult(await ensureMandatoryConsents(context, dataSource: backend)),
      child: const Text('go'),
    ),
  );
}

void main() {
  // The gate first sends what a failed sign-up left on the phone.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('which accounts are asked', () {
    test('the mandatory keys are the Terms and the Privacy Policy; the notice is the chat\'s', () {
      expect(AccountConsentKeys.mandatory, [_terms, _privacy]);
    });

    test('a text the server does not know is never asked for (builds 42 and 43)', () {
      const older = AccountConsentsSnapshot(decisions: {}, catalog: {});
      expect(missingMandatoryKeys(older), isEmpty);
    });

    test('nothing recorded, one missing, or an older version: asked', () {
      expect(mandatoryConsentsMissing(_snapshot({})), isTrue);
      expect(mandatoryConsentsMissing(_snapshot({_terms: _decision('v2')})), isTrue);
      expect(
        mandatoryConsentsMissing(_snapshot({..._all, _privacy: _decision('v1')})),
        isTrue,
      );
      expect(
        mandatoryConsentsMissing(_snapshot({..._all, _privacy: _decision('v3', granted: false)})),
        isTrue,
      );
    });

    test('an existing account (Terms v1, no emergency notice) is asked for the Terms only', () {
      final snapshot = _snapshot({_terms: _decision('v1'), _privacy: _decision('v3')});
      expect(missingMandatoryKeys(snapshot), [_terms]);
    });

    test('a missing or old emergency notice never blocks the app', () {
      expect(missingMandatoryKeys(_snapshot({..._all}..remove(_emergency))), isEmpty);
      expect(missingMandatoryKeys(_snapshot({..._all, _emergency: _decision('v0')})), isEmpty);
    });

    test('everything accepted at the current version: not asked', () {
      expect(mandatoryConsentsMissing(_snapshot(_all)), isFalse);
    });
  });

  group('the blocking pages', () {
    testWidgets('only the Terms and the Privacy Policy are asked at the start', (tester) async {
      final backend = _Backend(_snapshot({}));
      bool? accepted;
      await tester.pumpWidget(_starter(backend, (value) => accepted = value));

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(find.text('Prima di continuare'), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull); // not ticked yet
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(backend.set, [_terms, _privacy]);
      expect(accepted, isTrue);
      expect(find.text('Quokka non gestisce le urgenze'), findsNothing);
    });

    testWidgets('an account that only lacks the notice goes straight in', (tester) async {
      final backend = _Backend(_snapshot({..._all}..remove(_emergency)));
      bool? accepted;
      await tester.pumpWidget(_starter(backend, (value) => accepted = value));

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(accepted, isFalse); // nothing was asked
      expect(find.byType(CheckboxListTile), findsNothing);
      expect(backend.set, isEmpty);
    });

    testWidgets('an owner who already accepted everything is never asked', (tester) async {
      final backend = _Backend(_snapshot(_all));
      bool? accepted;
      await tester.pumpWidget(_starter(backend, (value) => accepted = value));

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(accepted, isFalse);
      expect(find.byType(CheckboxListTile), findsNothing);
    });

    testWidgets('when the answer cannot be recorded it says so and stays', (tester) async {
      final backend = _Backend(_snapshot({}), failSet: true);
      await tester.pumpWidget(_app((_) => ConsentGatePage(dataSource: backend)));

      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(find.textContaining('Non siamo riusciti a registrare'), findsOneWidget);
      expect(find.text('Prima di continuare'), findsOneWidget);
    });

    testWidgets('the version sent is the one of the catalogue the owner can open', (tester) async {
      final backend = _Backend(_snapshot({}));
      await tester.pumpWidget(
        _app(
          (_) => ConsentGatePage(
            dataSource: backend,
            catalogVersions: const {_terms: 'v7', _privacy: 'v8'},
          ),
        ),
      );
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(backend.declared, {_terms: 'v7', _privacy: 'v8'});
    });

    testWidgets('a text that changed is read again and asked again, not recorded', (tester) async {
      // The page was opened with v2/v3; the server holds v3/v4 now.
      final backend = _Backend(
        AccountConsentsSnapshot(
          decisions: const {},
          catalog: const {
            _terms: ConsentCatalogEntry(version: 'v3', text: 'termini nuovi'),
            _privacy: ConsentCatalogEntry(version: 'v4', text: 'informativa nuova'),
          },
        ),
      )..serverVersions = {_terms: 'v3', _privacy: 'v4'};
      await tester.pumpWidget(
        _app(
          (_) => ConsentGatePage(
            dataSource: backend,
            catalogVersions: const {_terms: 'v2', _privacy: 'v3'},
          ),
        ),
      );
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(backend.set, isEmpty); // nothing was recorded for a text that was not current
      expect(find.textContaining('Il testo è cambiato'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);

      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(backend.declared, {_terms: 'v3', _privacy: 'v4'});
    });

    testWidgets('if no newer text can be shown it says the app must be updated', (tester) async {
      // Refused, and the catalogue holds the same versions the page already had.
      final backend = _Backend(_snapshot({}))..serverVersions = {_terms: 'v9', _privacy: 'v9'};
      await tester.pumpWidget(
        _app(
          (_) => ConsentGatePage(
            dataSource: backend,
            catalogVersions: const {_terms: 'v2', _privacy: 'v3'},
          ),
        ),
      );
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(find.textContaining("versione più recente dell'app"), findsOneWidget);
      expect(backend.set, isEmpty);
      // Leaving stays possible.
      expect(find.text('Esci'), findsOneWidget);
    });

    testWidgets('"Altre possibilità" offers the data and the deletion, no pause', (tester) async {
      final backend = _Backend(_snapshot({}));
      await tester.pumpWidget(_app((_) => ConsentGatePage(dataSource: backend)));
      await tester.ensureVisible(find.byKey(const Key('consentGateOtherOptions')));
      await tester.tap(find.byKey(const Key('consentGateOtherOptions')));
      await tester.pumpAndSettle();

      expect(find.text('Scarica i miei dati'), findsOneWidget);
      expect(find.text('Elimina account'), findsOneWidget);
      expect(find.textContaining('pausa'), findsNothing);
      // Nothing was accepted by looking at them.
      expect(backend.set, isEmpty);
    });

    testWidgets('"Esci" leaves instead of accepting', (tester) async {
      var left = 0;
      await tester.pumpWidget(
        _app(
          (_) => ConsentGatePage(
            dataSource: _Backend(_snapshot({})),
            onLeave: (_) async => left++,
          ),
        ),
      );

      await tester.tap(find.text('Esci'));
      await tester.pump();

      expect(left, 1);
    });
  });
}
