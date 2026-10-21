import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vet_app_mobile/features/language/data/language_store.dart';
import 'package:vet_app_mobile/features/language/domain/app_language.dart';
import 'package:vet_app_mobile/features/language/presentation/widgets/first_run_language_gate.dart';
import 'package:vet_app_mobile/features/language/presentation/widgets/language_settings_section.dart';
import 'package:vet_app_mobile/features/settings/data/unit_settings_store.dart';
import 'package:vet_app_mobile/features/settings/domain/unit_system.dart';
import 'package:vet_app_mobile/l10n/date_formats.dart';
import 'package:vet_app_mobile/l10n/l10n.dart';

List<AppLanguageVariant> _only(List<String> languages) =>
    availableLanguageVariants([for (final code in languages) Locale(code)]);

Widget _gate() => const MaterialApp(
      home: FirstRunLanguageGate(child: Scaffold(body: Text('registrazione'))),
    );

Widget _settingsSection() => MaterialApp(
      home: Scaffold(
        body: ListView(
          children: [LanguageSettingsSection(expanded: true, onToggle: (_) {})],
        ),
      ),
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LanguageStore.instance.resetForTest();
  });

  tearDown(LanguageStore.instance.resetForTest);

  test('the ARB files present are what decides which languages are available', () {
    final arbLanguages = Directory('lib/l10n')
        .listSync()
        .whereType<File>()
        .map((file) => file.uri.pathSegments.last)
        .where((name) => RegExp(r'^app_[a-z]{2}\.arb$').hasMatch(name))
        .map((name) => name.substring(4, 6))
        .toSet();
    final supported = AppLocalizations.supportedLocales.map((l) => l.languageCode).toSet();
    expect(supported, arbLanguages);
  });

  testWidgets('with a single translation the first-run page is skipped', (tester) async {
    LanguageStore.availableOverride = () => _only(['it']);
    await tester.pumpWidget(_gate());

    expect(LanguageStore.instance.needsFirstRunChoice, isFalse);
    expect(find.text('registrazione'), findsOneWidget);
    expect(find.text('Scegli la tua lingua'), findsNothing);
  });

  testWidgets('with two translations the first-run page appears, then registration',
      (tester) async {
    LanguageStore.availableOverride = () => _only(['it', 'en']);
    await tester.pumpWidget(_gate());

    expect(find.text('Scegli la tua lingua'), findsOneWidget);
    expect(find.text('registrazione'), findsNothing);
    expect(find.text('Italiano'), findsOneWidget);
    expect(find.text('English (UK)'), findsOneWidget);
    expect(find.text('English (US)'), findsOneWidget);
    expect(find.text('English (Australia)'), findsOneWidget);
    expect(find.text('🇦🇺'), findsOneWidget);

    await tester.tap(find.text('English (UK)'));
    await tester.pumpAndSettle();

    expect(find.text('registrazione'), findsOneWidget);
    expect(LanguageStore.instance.variant.id, 'en-GB');
    expect(LanguageStore.instance.hasChosen, isTrue);
  });

  testWidgets('the Settings section exists only with two translations', (tester) async {
    LanguageStore.availableOverride = () => _only(['it']);
    await tester.pumpWidget(_settingsSection());
    expect(find.text('🇮🇹 LINGUA · ITALIANO'), findsNothing);

    LanguageStore.availableOverride = () => _only(['it', 'en']);
    await tester.pumpWidget(_settingsSection());
    await tester.pump();
    expect(find.text('🇮🇹 LINGUA · ITALIANO'), findsOneWidget);
    expect(find.text('English (US)'), findsOneWidget);
    // The open section scrolls itself into view after a short delay.
    await tester.pump(const Duration(seconds: 1));
  });

  test('a saved choice wins over the phone language and is not asked again', () async {
    SharedPreferences.setMockInitialValues({'vet_app.language_variant': 'en-AU'});
    LanguageStore.availableOverride = () => _only(['it', 'en']);
    LanguageStore.deviceLocale = () => const Locale('it', 'IT');

    await LanguageStore.instance.ensureLoaded();

    expect(LanguageStore.instance.variant.id, 'en-AU');
    expect(LanguageStore.instance.needsFirstRunChoice, isFalse);
    expect(AppLocaleHolder.current, const Locale('en', 'AU'));
    expect(appDecimalSeparator(), '.');
  });

  test('without a saved choice the phone language is proposed', () async {
    LanguageStore.availableOverride = () => _only(['it', 'en']);
    LanguageStore.deviceLocale = () => const Locale('en', 'GB');

    await LanguageStore.instance.ensureLoaded();

    expect(LanguageStore.instance.variant.id, 'en-GB');
    expect(LanguageStore.instance.needsFirstRunChoice, isTrue);
  });

  group('suggestLanguageVariant', () {
    final all = _only(['it', 'en', 'de']);

    test('exact country match', () {
      expect(suggestLanguageVariant(const Locale('en', 'AU'), all).id, 'en-AU');
      expect(suggestLanguageVariant(const Locale('en', 'US'), all).id, 'en-US');
    });

    test('English from elsewhere maps to the nearest variant', () {
      expect(suggestLanguageVariant(const Locale('en', 'IE'), all).id, 'en-GB');
      expect(suggestLanguageVariant(const Locale('en', 'NZ'), all).id, 'en-AU');
      expect(suggestLanguageVariant(const Locale('en', 'CA'), all).id, 'en-US');
      expect(suggestLanguageVariant(const Locale('en'), all).id, 'en-US');
    });

    test('a language without translation falls back to Italian', () {
      expect(suggestLanguageVariant(const Locale('ja', 'JP'), all).id, 'it');
      expect(suggestLanguageVariant(const Locale('fr', 'FR'), all).id, 'it');
    });
  });

  group('units follow the chosen country unless the owner picked them', () {
    setUp(UnitSettingsStore.instance.resetForTest);
    tearDown(UnitSettingsStore.instance.resetForTest);

    test('default units move with the language', () async {
      LanguageStore.availableOverride = () => _only(['it', 'en']);
      await LanguageStore.instance.choose(languageVariantById('en-GB')!);
      expect(UnitSettingsStore.instance.system, UnitSystem.uk);
      await LanguageStore.instance.choose(languageVariantById('en-US')!);
      expect(UnitSettingsStore.instance.system, UnitSystem.us);
      await LanguageStore.instance.choose(languageVariantById('en-AU')!);
      expect(UnitSettingsStore.instance.system, UnitSystem.metric);
    });

    test('units picked by hand are never overwritten', () async {
      LanguageStore.availableOverride = () => _only(['it', 'en']);
      await UnitSettingsStore.instance.setSystem(UnitSystem.metric);
      await LanguageStore.instance.choose(languageVariantById('en-US')!);
      expect(UnitSettingsStore.instance.system, UnitSystem.metric);
    });

    test('defaultUnitsForLocale maps the English variants', () {
      expect(defaultUnitsForLocale('GB'), UnitSystem.uk);
      expect(defaultUnitsForLocale('US'), UnitSystem.us);
      expect(defaultUnitsForLocale('AU'), UnitSystem.metric);
      expect(defaultUnitsForLocale('IT'), UnitSystem.metric);
    });
  });
}
