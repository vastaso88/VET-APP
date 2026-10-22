
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vet_app_mobile/features/language/data/language_store.dart';
import 'package:vet_app_mobile/features/language/domain/app_language.dart';
import 'package:vet_app_mobile/features/language/presentation/widgets/language_selector.dart';
import 'package:vet_app_mobile/l10n/l10n.dart';

Widget _app() => ListenableBuilder(
      listenable: LanguageStore.instance,
      builder: (_, __) => MaterialApp(
        locale: LanguageStore.instance.locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: Center(child: LanguageSelector())),
      ),
    );

/// Opens the compact selector and taps the entry for [language].
Future<void> _pickLanguage(WidgetTester tester, String language) async {
  await tester.tap(find.byType(LanguageSelector));
  await tester.pumpAndSettle();
  await tester.tap(find.text(language).last);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    LanguageStore.instance.resetForTest();
  });
  tearDown(LanguageStore.instance.resetForTest);

  final english = availableLanguageVariants([const Locale('en')]);
  final german = availableLanguageVariants([const Locale('de')]);

  group('knownVariantForDevice', () {
    test('the phone country picks the variant, with obvious neighbours', () {
      expect(knownVariantForDevice(const Locale('it', 'GB'), english)?.id, 'en-GB');
      expect(knownVariantForDevice(const Locale('en', 'US'), english)?.id, 'en-US');
      expect(knownVariantForDevice(const Locale('it', 'AU'), english)?.id, 'en-AU');
      expect(knownVariantForDevice(const Locale('en', 'IE'), english)?.id, 'en-GB');
      expect(knownVariantForDevice(const Locale('en', 'NZ'), english)?.id, 'en-AU');
      expect(knownVariantForDevice(const Locale('de', 'LI'), german)?.id, 'de-CH');
      expect(knownVariantForDevice(const Locale('it', 'AT'), german)?.id, 'de-AT');
    });

    test('an unknown country is not guessed: Italy, Spain, Canada, no country', () {
      for (final device in [
        const Locale('it', 'IT'),
        const Locale('es', 'ES'),
        const Locale('en', 'CA'),
        const Locale('en'),
      ]) {
        expect(knownVariantForDevice(device, english), isNull, reason: '$device');
      }
      expect(knownVariantForDevice(const Locale('es', 'ES'), german), isNull);
    });

    test('a language with a single variant is never asked', () {
      final spanish = availableLanguageVariants([const Locale('es')]);
      expect(knownVariantForDevice(const Locale('it', 'IT'), spanish)?.id, 'es');
    });
  });

  group('the selector keeps the last variant per language', () {
    testWidgets('en-AU → Español → English comes back to en-AU', (tester) async {
      LanguageStore.deviceLocale = () => const Locale('it', 'IT');
      await tester.pumpWidget(_app());
      await LanguageStore.instance.choose(languageVariantById('en-AU')!);
      await tester.pumpAndSettle();

      await _pickLanguage(tester, 'Español');
      expect(LanguageStore.instance.variant.id, 'es');

      await _pickLanguage(tester, 'English');
      expect(LanguageStore.instance.variant.id, 'en-AU');
      expect(find.byType(SimpleDialog), findsNothing, reason: 'nothing to ask: we remember');
    });

    test('the memory survives a restart', () async {
      LanguageStore.deviceLocale = () => const Locale('it', 'IT');
      await LanguageStore.instance.choose(languageVariantById('en-US')!);
      await LanguageStore.instance.choose(languageVariantById('de-CH')!);
      await LanguageStore.instance.choose(languageVariantById('es')!);

      LanguageStore.instance.resetForTest();
      LanguageStore.deviceLocale = () => const Locale('it', 'IT');
      await LanguageStore.instance.ensureLoaded();

      expect(LanguageStore.instance.variant.id, 'es');
      expect(LanguageStore.instance.knownVariantForLanguage('en')?.id, 'en-US');
      expect(LanguageStore.instance.knownVariantForLanguage('de')?.id, 'de-CH');
    });
  });

  group('a phone that does not say which English', () {
    testWidgets('an Italian phone is asked, and the answer is applied', (tester) async {
      LanguageStore.deviceLocale = () => const Locale('it', 'IT');
      await tester.pumpWidget(_app());
      await LanguageStore.instance.choose(languageVariantById('it')!);
      await tester.pumpAndSettle();

      await _pickLanguage(tester, 'English');
      expect(LanguageStore.instance.variant.id, 'it', reason: 'no silent en-GB / en-US');
      expect(find.byType(SimpleDialog), findsOneWidget);
      expect(find.text('English (UK)'), findsOneWidget);
      expect(find.text('English (US)'), findsOneWidget);
      expect(find.text('English (Australia)'), findsOneWidget);

      await tester.tap(find.text('English (Australia)'));
      await tester.pumpAndSettle();
      expect(LanguageStore.instance.variant.id, 'en-AU');
      expect(find.byType(SimpleDialog), findsNothing);
    });

    testWidgets('dismissing the question changes nothing', (tester) async {
      LanguageStore.deviceLocale = () => const Locale('es', 'ES');
      await tester.pumpWidget(_app());
      await LanguageStore.instance.choose(languageVariantById('es')!);
      await tester.pumpAndSettle();

      await _pickLanguage(tester, 'English');
      await tester.tapAt(const Offset(2, 2));
      await tester.pumpAndSettle();
      expect(LanguageStore.instance.variant.id, 'es');
    });

    testWidgets('a UK phone gets en-GB straight away', (tester) async {
      LanguageStore.deviceLocale = () => const Locale('it', 'GB');
      await tester.pumpWidget(_app());
      await LanguageStore.instance.choose(languageVariantById('it')!);
      await tester.pumpAndSettle();

      await _pickLanguage(tester, 'English');
      expect(LanguageStore.instance.variant.id, 'en-GB');
      expect(find.byType(SimpleDialog), findsNothing);
    });

    testWidgets('German from a Spanish phone asks DE / AT / CH', (tester) async {
      LanguageStore.deviceLocale = () => const Locale('es', 'ES');
      await tester.pumpWidget(_app());
      await LanguageStore.instance.choose(languageVariantById('es')!);
      await tester.pumpAndSettle();

      await _pickLanguage(tester, 'Deutsch');
      expect(find.text('Deutsch (Deutschland)'), findsOneWidget);
      expect(find.text('Deutsch (Österreich)'), findsOneWidget);
      expect(find.text('Deutsch (Schweiz)'), findsOneWidget);
    });
  });
}
