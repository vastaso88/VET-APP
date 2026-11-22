import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/account_consents/application/consent_gate.dart';
import 'package:vet_app_mobile/features/account_consents/data/account_consents_remote_data_source.dart';
import 'package:vet_app_mobile/features/account_consents/domain/account_consent_models.dart';
import 'package:vet_app_mobile/features/account_consents/presentation/pages/consent_gate_page.dart';
import 'package:vet_app_mobile/features/account_consents/presentation/pages/emergency_notice_gate_page.dart';
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

  @override
  Future<Result<AccountConsentsSnapshot>> fetch() async => Result.success(snapshot);

  @override
  Future<Result<AccountConsentsSnapshot>> setConsent({
    required String consentKey,
    required bool granted,
  }) async {
    if (failSet) return Result.failure(const AppNetworkError(code: 'consent_http_500'));
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
  group('which accounts are asked', () {
    test('the mandatory keys are the three the server enforces', () {
      expect(AccountConsentKeys.mandatory, [_terms, _privacy, _emergency]);
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

    test('an existing account (Terms v1, no emergency notice) is asked for both', () {
      final snapshot = _snapshot({_terms: _decision('v1'), _privacy: _decision('v3')});
      expect(missingMandatoryKeys(snapshot), [_terms, _emergency]);
    });

    test('the emergency notice at an older version is asked again, alone', () {
      final snapshot = _snapshot({..._all, _emergency: _decision('v0')});
      expect(missingMandatoryKeys(snapshot), [_emergency]);
    });

    test('everything accepted at the current version: not asked', () {
      expect(mandatoryConsentsMissing(_snapshot(_all)), isFalse);
    });
  });

  group('the blocking pages', () {
    testWidgets('Terms and Privacy first, then the emergency notice on its own page', (
      tester,
    ) async {
      final backend = _Backend(_snapshot({}));
      bool? accepted;
      await tester.pumpWidget(_starter(backend, (value) => accepted = value));

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      // Step 1: Terms and Privacy.
      expect(find.text('Prima di continuare'), findsOneWidget);
      var button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull); // not ticked yet
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(backend.set, [_terms, _privacy]);

      // Step 2: the clause, with its own box.
      expect(find.text('Quokka non gestisce le urgenze'), findsOneWidget);
      button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(backend.set, [_terms, _privacy, _emergency]);
      expect(accepted, isTrue);
      expect(find.text('Quokka non gestisce le urgenze'), findsNothing);
    });

    testWidgets('an account that only lacks the clause sees only its page', (tester) async {
      final backend = _Backend(_snapshot({..._all}..remove(_emergency)));
      bool? accepted;
      await tester.pumpWidget(_starter(backend, (value) => accepted = value));

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(find.text('Prima di continuare'), findsNothing);
      expect(find.text('Quokka non gestisce le urgenze'), findsOneWidget);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(backend.set, [_emergency]); // only what was missing
      expect(accepted, isTrue);
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

  group('the emergency-notice page (docs/compliance/22 §5)', () {
    testWidgets('title, short text in view, box NOT pre-ticked, Continue off', (tester) async {
      await tester.pumpWidget(
        _app((_) => EmergencyNoticeGatePage(dataSource: _Backend(_snapshot({})))),
      );

      expect(find.text('Quokka non gestisce le urgenze'), findsOneWidget);
      // The short version is on the page itself, not behind a link.
      expect(find.textContaining('Non aspettare la risposta dell'), findsOneWidget);
      final box = tester.widget<CheckboxListTile>(find.byType(CheckboxListTile));
      expect(box.value, isFalse);
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
      expect(
          find.text(
              'Ho capito che Quokka non gestisce le urgenze e non lo uso in caso di emergenza.'),
          findsOneWidget);
      expect(find.text('Leggi il testo completo nei Termini di Servizio'), findsOneWidget);
    });

    testWidgets('"Non accetto" is as big as "Continua" and leads to the alternatives', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app((_) => EmergencyNoticeGatePage(dataSource: _Backend(_snapshot({})))),
      );

      final continueSize = tester.getSize(find.byType(FilledButton));
      final declineSize = tester.getSize(find.byType(OutlinedButton));
      expect(declineSize.width, continueSize.width);
      expect(declineSize.height, continueSize.height);

      await tester.tap(find.text('Non accetto'));
      await tester.pumpAndSettle();

      expect(find.text('Senza questa conferma non puoi usare Quokka'), findsOneWidget);
      expect(find.text('Scarica i miei dati'), findsOneWidget);
      expect(find.text('Elimina account'), findsOneWidget);
      expect(find.text('Esci'), findsOneWidget);
    });

    testWidgets('a failed recording says so and stays', (tester) async {
      final backend = _Backend(_snapshot({}), failSet: true);
      await tester.pumpWidget(_app((_) => EmergencyNoticeGatePage(dataSource: backend)));

      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(find.textContaining('Non siamo riusciti a registrare'), findsOneWidget);
      expect(find.text('Quokka non gestisce le urgenze'), findsOneWidget);
    });
  });
}
