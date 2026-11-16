import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/account_consents/application/consent_gate.dart';
import 'package:vet_app_mobile/features/account_consents/data/account_consents_remote_data_source.dart';
import 'package:vet_app_mobile/features/account_consents/domain/account_consent_models.dart';
import 'package:vet_app_mobile/features/account_consents/presentation/pages/consent_gate_page.dart';
import 'package:vet_app_mobile/l10n/l10n.dart';
import 'package:vet_app_mobile/shared/errors/app_network_error.dart';
import 'package:vet_app_mobile/shared/types/result.dart';

const _terms = AccountConsentKeys.termsOfService;
const _privacy = AccountConsentKeys.privacyPolicy;

ConsentDecision _decision(String version, {bool granted = true}) =>
    ConsentDecision(granted: granted, version: version, decidedAt: DateTime(2026, 11, 16));

AccountConsentsSnapshot _snapshot(Map<String, ConsentDecision> decisions) =>
    AccountConsentsSnapshot(
      decisions: decisions,
      catalog: const {
        _terms: ConsentCatalogEntry(version: 'v2', text: 'termini'),
        _privacy: ConsentCatalogEntry(version: 'v3', text: 'informativa'),
      },
    );

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

void main() {
  group('which accounts are asked', () {
    test('nothing recorded, one missing, or an older version: asked', () {
      expect(mandatoryConsentsMissing(_snapshot({})), isTrue);
      expect(mandatoryConsentsMissing(_snapshot({_terms: _decision('v2')})), isTrue);
      expect(
        mandatoryConsentsMissing(_snapshot({_terms: _decision('v2'), _privacy: _decision('v1')})),
        isTrue,
      );
      expect(
        mandatoryConsentsMissing(
          _snapshot({_terms: _decision('v2'), _privacy: _decision('v3', granted: false)}),
        ),
        isTrue,
      );
    });

    test('both accepted at the current version: not asked', () {
      expect(
        mandatoryConsentsMissing(_snapshot({_terms: _decision('v2'), _privacy: _decision('v3')})),
        isFalse,
      );
    });
  });

  group('the blocking page', () {
    testWidgets('cannot continue until the box is ticked, then records both and closes', (
      tester,
    ) async {
      final backend = _Backend(_snapshot({}));
      bool? accepted;
      await tester.pumpWidget(
        _app(
          (context) => TextButton(
            onPressed: () async => accepted = await ensureMandatoryConsents(
              context,
              dataSource: backend,
            ),
            child: const Text('go'),
          ),
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(find.text('Prima di continuare'), findsOneWidget);
      var button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull); // not ticked yet

      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNotNull);

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(backend.set, [_terms, _privacy]);
      expect(accepted, isTrue);
      expect(find.text('Prima di continuare'), findsNothing);
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

    testWidgets('an owner who already accepted is never asked', (tester) async {
      final backend = _Backend(_snapshot({_terms: _decision('v2'), _privacy: _decision('v3')}));
      bool? accepted;
      await tester.pumpWidget(
        _app(
          (context) => TextButton(
            onPressed: () async => accepted = await ensureMandatoryConsents(
              context,
              dataSource: backend,
            ),
            child: const Text('go'),
          ),
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(accepted, isFalse);
      expect(find.text('Prima di continuare'), findsNothing);
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
