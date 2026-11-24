import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/account_consents/data/account_consents_remote_data_source.dart';
import 'package:vet_app_mobile/features/account_consents/domain/account_consent_models.dart';
import 'package:vet_app_mobile/features/account_consents/presentation/widgets/account_consents_group.dart';
import 'package:vet_app_mobile/features/age/domain/age_status.dart';
import 'package:vet_app_mobile/features/marketplace/presentation/marketplace_rules_acceptance.dart';
import 'package:vet_app_mobile/l10n/app_localizations.dart';
import 'package:vet_app_mobile/shared/types/result.dart';

ConsentDecision _decision(String version, {bool granted = true}) =>
    ConsentDecision(
        granted: granted, version: version, decidedAt: DateTime(2026, 11, 20));

class _FakeConsents implements AccountConsentsRemoteDataSource {
  _FakeConsents({this.decisions = const {}, this.catalogHasRules = true});

  Map<String, ConsentDecision> decisions;
  final bool catalogHasRules;
  final List<(String, bool)> saved = [];

  AccountConsentsSnapshot get _snapshot => AccountConsentsSnapshot(
        decisions: decisions,
        catalog: {
          'marketing_email':
              const ConsentCatalogEntry(version: 'v1', text: 'Testo e-mail.'),
          'diagnostics':
              const ConsentCatalogEntry(version: 'v1', text: 'Testo errori.'),
          if (catalogHasRules)
            'marketplace_rules': const ConsentCatalogEntry(
                version: 'v1', text: 'Regole del Mercatino\n1. Test.'),
        },
      );

  @override
  Future<Result<AccountConsentsSnapshot>> fetch() async =>
      Result.success(_snapshot);

  @override
  Future<Result<AccountConsentsSnapshot>> setConsent({
    required String consentKey,
    required bool granted,
    String? shownVersion,
  }) async {
    saved.add((consentKey, granted));
    decisions = {...decisions, consentKey: _decision('v1', granted: granted)};
    return Result.success(_snapshot);
  }
}

Widget _app(Widget child) => MaterialApp(
      locale: const Locale('it'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  group('the optional consents as switches outside Settings', () {
    Future<void> open(WidgetTester tester, _FakeConsents source,
        {AgeBand band = AgeBand.adult}) async {
      await tester.pumpWidget(_app(AccountConsentsGroup(
        dataSource: source,
        band: band,
        diagnosticsAvailable: true,
      )));
      await tester.pumpAndSettle();
    }

    testWidgets('same words as Settings, switches off, marketing for adults',
        (tester) async {
      await open(tester, _FakeConsents());

      expect(find.text('Email di marketing: novità e consigli di Quokka'),
          findsOneWidget);
      expect(find.text('Invia rapporti sugli errori'), findsOneWidget);
      for (final tile
          in tester.widgetList<SwitchListTile>(find.byType(SwitchListTile))) {
        expect(tile.value, isFalse);
      }
    });

    testWidgets('a minor never sees the marketing switch', (tester) async {
      await open(tester, _FakeConsents(), band: AgeBand.minor);

      expect(find.byKey(const ValueKey('account-consent-marketing_email')),
          findsNothing);
      expect(find.byKey(const ValueKey('account-consent-diagnostics')),
          findsOneWidget);
    });

    testWidgets(
        'turning one on shows its text first, and records only after «Attiva»',
        (tester) async {
      final source = _FakeConsents();
      await open(tester, source);

      await tester
          .tap(find.byKey(const ValueKey('account-consent-marketing_email')));
      await tester.pumpAndSettle();
      expect(find.text('Testo e-mail.'), findsOneWidget);
      expect(source.saved, isEmpty);

      await tester.tap(find.byKey(const ValueKey('consent-activate-yes')));
      await tester.pumpAndSettle();

      expect(source.saved, [('marketing_email', true)]);
    });

    testWidgets('«Non ora» records nothing', (tester) async {
      final source = _FakeConsents();
      await open(tester, source);

      await tester
          .tap(find.byKey(const ValueKey('account-consent-marketing_email')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('consent-activate-not-now')));
      await tester.pumpAndSettle();

      expect(source.saved, isEmpty);
    });

    testWidgets('turning one off is one tap, no question', (tester) async {
      final source =
          _FakeConsents(decisions: {'marketing_email': _decision('v1')});
      await open(tester, source);

      await tester
          .tap(find.byKey(const ValueKey('account-consent-marketing_email')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('consent-activate-yes')), findsNothing);
      expect(source.saved, [('marketing_email', false)]);
    });

    testWidgets(
        'after a new version of the text: «Da confermare» and the switch is off',
        (tester) async {
      await open(tester,
          _FakeConsents(decisions: {'marketing_email': _decision('v0')}));

      final tile = tester.widget<SwitchListTile>(
          find.byKey(const ValueKey('account-consent-marketing_email')));
      expect(tile.value, isFalse);
      expect(find.text('Da confermare'), findsOneWidget);
    });
  });

  group('the Mercatino rules: an acceptance, with an unticked box', () {
    Future<bool?> run(WidgetTester tester, _FakeConsents source,
        {List<Future<void> Function()> steps = const []}) async {
      bool? result;
      await tester.pumpWidget(_app(Builder(
        builder: (context) => ElevatedButton(
          key: const ValueKey('go'),
          onPressed: () async => result =
              await ensureMarketplaceRulesAccepted(context, dataSource: source),
          child: const Text('vai'),
        ),
      )));
      await tester.tap(find.byKey(const ValueKey('go')));
      await tester.pumpAndSettle();
      for (final step in steps) {
        await step();
        await tester.pumpAndSettle();
      }
      return result;
    }

    testWidgets('already accepted (current version): no question',
        (tester) async {
      final source =
          _FakeConsents(decisions: {'marketplace_rules': _decision('v1')});

      final result = await run(tester, source);

      expect(result, isTrue);
      expect(find.byKey(const ValueKey('marketplace-rules-checkbox')),
          findsNothing);
    });

    testWidgets(
        'the box starts unticked and «Continua» waits for it; accepting records it',
        (tester) async {
      final source = _FakeConsents();

      final result = await run(tester, source, steps: [
        () async {
          expect(find.textContaining('Regole del Mercatino'), findsWidgets);
          expect(
              tester
                  .widget<CheckboxListTile>(
                      find.byKey(const ValueKey('marketplace-rules-checkbox')))
                  .value,
              isFalse);
          expect(
              tester
                  .widget<TextButton>(
                      find.byKey(const ValueKey('marketplace-rules-continue')))
                  .onPressed,
              isNull);
          await tester
              .tap(find.byKey(const ValueKey('marketplace-rules-checkbox')));
          await tester.pump();
          await tester
              .tap(find.byKey(const ValueKey('marketplace-rules-continue')));
        },
      ]);

      expect(result, isTrue);
      expect(source.saved, [('marketplace_rules', true)]);
    });

    testWidgets('«Non ora» does not accept and does not go on', (tester) async {
      final source = _FakeConsents();

      final result = await run(tester, source, steps: [
        () async =>
            tester.tap(find.byKey(const ValueKey('marketplace-rules-not-now'))),
      ]);

      expect(result, isFalse);
      expect(source.saved, isEmpty);
    });

    testWidgets('an older version of the rules is asked again', (tester) async {
      final source =
          _FakeConsents(decisions: {'marketplace_rules': _decision('v0')});

      await run(tester, source);

      expect(find.byKey(const ValueKey('marketplace-rules-checkbox')),
          findsOneWidget);
    });

    testWidgets('a catalog without the rules asks nothing', (tester) async {
      final result = await run(tester, _FakeConsents(catalogHasRules: false));

      expect(result, isTrue);
      expect(find.byKey(const ValueKey('marketplace-rules-checkbox')),
          findsNothing);
    });
  });
}
