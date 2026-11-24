import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/account_consents/data/account_consents_remote_data_source.dart';
import 'package:vet_app_mobile/features/account_consents/domain/account_consent_models.dart';
import 'package:vet_app_mobile/features/account_consents/domain/consent_availability.dart';
import 'package:vet_app_mobile/features/account_consents/presentation/pages/consent_choices_page.dart';
import 'package:vet_app_mobile/features/age/domain/age_status.dart';
import 'package:vet_app_mobile/l10n/app_localizations.dart';
import 'package:vet_app_mobile/shared/errors/app_network_error.dart';
import 'package:vet_app_mobile/shared/types/result.dart';

class _FakeConsents implements AccountConsentsRemoteDataSource {
  _FakeConsents({this.failFetch = false});

  final bool failFetch;
  final List<String> saved = [];

  static const _snapshot = AccountConsentsSnapshot(
    decisions: {},
    catalog: {
      'diagnostics': ConsentCatalogEntry(version: 'v1', text: 'Testo errori.'),
      'analytics': ConsentCatalogEntry(version: 'v1', text: 'Testo analisi.'),
      'marketing_email': ConsentCatalogEntry(version: 'v1', text: 'Testo e-mail.'),
    },
  );

  @override
  Future<Result<AccountConsentsSnapshot>> fetch() async =>
      failFetch ? Result.failure(AppNetworkError()) : Result.success(_snapshot);

  @override
  Future<Result<AccountConsentsSnapshot>> setConsent({
    required String consentKey,
    required bool granted,
    String? shownVersion,
  }) async {
    if (granted) saved.add(consentKey);
    return Result.success(_snapshot);
  }
}

Future<void> _open(
  WidgetTester tester, {
  required bool isAdult,
  required _FakeConsents source,
  bool diagnostics = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('it'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              key: const ValueKey('open'),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => ConsentChoicesPage(
                  isAdult: isAdult,
                  dataSource: source,
                  diagnosticsAvailable: diagnostics,
                ),
              )),
              child: const Text('apri'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('open')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an adult sees the switches off, with the catalogue text', (tester) async {
    final source = _FakeConsents();
    await _open(tester, isAdult: true, source: source);

    expect(find.text('Cosa vuoi attivare?'), findsOneWidget);
    expect(find.text('Testo errori.'), findsOneWidget);
    expect(find.text('Testo e-mail.'), findsOneWidget);
    // No analytics tool exists: the switch is not there.
    expect(analyticsToolExists, isFalse);
    expect(find.text('Testo analisi.'), findsNothing);
    for (final tile in tester.widgetList<SwitchListTile>(find.byType(SwitchListTile))) {
      expect(tile.value, isFalse);
    }
  });

  testWidgets('"Salva le scelte" records only what was switched on', (tester) async {
    final source = _FakeConsents();
    await _open(tester, isAdult: true, source: source);

    await tester.tap(find.byKey(const ValueKey('consent-choice-marketing_email')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('consent-choices-save')));
    await tester.pumpAndSettle();

    expect(source.saved, ['marketing_email']);
    expect(find.text('Cosa vuoi attivare?'), findsNothing);
  });

  testWidgets('"Non ora" records nothing and leaves', (tester) async {
    final source = _FakeConsents();
    await _open(tester, isAdult: true, source: source);

    await tester.tap(find.byKey(const ValueKey('consent-choice-diagnostics')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('consent-choices-not-now')));
    await tester.pumpAndSettle();

    expect(source.saved, isEmpty);
    expect(find.text('Cosa vuoi attivare?'), findsNothing);
  });

  testWidgets('a minor is offered only the error reports', (tester) async {
    await _open(tester, isAdult: false, source: _FakeConsents());

    expect(find.text('Testo errori.'), findsOneWidget);
    expect(find.text('Testo e-mail.'), findsNothing);
  });

  testWidgets('a minor in a build with no error reports sees no screen at all', (tester) async {
    await _open(tester, isAdult: false, source: _FakeConsents(), diagnostics: false);

    expect(find.text('Cosa vuoi attivare?'), findsNothing);
    expect(find.byKey(const ValueKey('open')), findsOneWidget);
  });

  testWidgets('texts that cannot be read: the page steps aside, nothing is recorded',
      (tester) async {
    final source = _FakeConsents(failFetch: true);
    await _open(tester, isAdult: true, source: source);

    expect(find.text('Cosa vuoi attivare?'), findsNothing);
    expect(source.saved, isEmpty);
  });

  test('marketing is never offered to a declared minor', () {
    expect(marketingConsentOffered(AgeBand.minor), isFalse);
    expect(marketingConsentOffered(AgeBand.underMinimum), isFalse);
    expect(marketingConsentOffered(AgeBand.adult), isTrue);
    expect(marketingConsentOffered(AgeBand.unknown), isTrue);
  });
}
