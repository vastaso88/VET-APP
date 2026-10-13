import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vet_app_mobile/features/auth/presentation/pages/login_page.dart';
import 'package:vet_app_mobile/features/auth/presentation/pages/register_page.dart';
import 'package:vet_app_mobile/features/language/data/language_store.dart';
import 'package:vet_app_mobile/features/language/domain/app_language.dart';
import 'package:vet_app_mobile/features/language/presentation/widgets/language_selector.dart';
import 'package:vet_app_mobile/features/language/presentation/widgets/language_settings_section.dart';
import 'package:vet_app_mobile/l10n/l10n.dart';

Widget _app(Widget page) => ListenableBuilder(
      listenable: LanguageStore.instance,
      builder: (_, __) => MaterialApp(
        locale: LanguageStore.instance.locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: page,
      ),
    );

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    LanguageStore.instance.resetForTest();
  });
  tearDown(LanguageStore.instance.resetForTest);

  testWidgets('settings header shows flag and language even when collapsed',
      (tester) async {
    await tester.pumpWidget(_app(Scaffold(
      body: LanguageSettingsSection(expanded: false, onToggle: (_) {}),
    )));
    await tester.pumpAndSettle();
    expect(find.text('🇮🇹 LINGUA · ITALIANO'), findsOneWidget);
    await LanguageStore.instance.choose(languageVariantById('es')!);
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(LanguageSettingsSection));
    expect(
        find.text(
            '🇪🇸 ${context.l10n.languageSectionTitle.toUpperCase()} · ESPAÑOL'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('existing validation errors and banner change language too',
      (tester) async {
    await tester.pumpWidget(_app(const LoginPage()));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(appL10n.authLoginButton));
    await tester.tap(find.text(appL10n.authLoginButton));
    await tester.pumpAndSettle();
    expect(find.text(appL10n.authEmailRequired), findsOneWidget);
    await LanguageStore.instance.choose(languageVariantById('es')!);
    await tester.pumpAndSettle();
    expect(find.text(appL10n.authEmailRequired), findsOneWidget);
    expect(find.text(appL10n.authBannerCheckFieldsTitle), findsOneWidget);
    expect(find.text(appL10n.authLoginFieldsInvalidMessage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final locale in ['it', 'en', 'es']) {
    for (final entry in <String, Widget>{
      'login': const LoginPage(),
      'register': const RegisterPage(),
      'settings': Scaffold(
        body: SingleChildScrollView(
          child: LanguageSettingsSection(expanded: true, onToggle: (_) {}),
        ),
      ),
    }.entries) {
      testWidgets(
          '${entry.key} uses the shared selector in $locale at mobile width',
          (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await LanguageStore.instance
            .choose(languageVariantById(locale == 'en' ? 'en-GB' : locale)!);
        await tester.pumpWidget(_app(entry.value));
        await tester.pumpAndSettle();
        expect(find.byType(LanguageSelector), findsOneWidget);
        expect(
            find.descendant(
                of: find.byType(LanguageSelector),
                matching: find.text(LanguageStore.instance.variant.flag)),
            findsOneWidget);
        await tester.tap(find.byType(LanguageSelector));
        await tester.pumpAndSettle();
        expect(find.text('Italiano'), findsWidgets);
        expect(find.text('English'), findsWidgets);
        expect(find.text('Español'), findsWidgets);
        expect(find.text('🇮🇹'), findsWidgets);
        expect(find.text(LanguageStore.instance.variantForLanguage('en').flag),
            findsWidgets);
        expect(find.text('🇪🇸'), findsWidgets);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }

  testWidgets(
      'changing language on login keeps the typed email and translates the page',
      (tester) async {
    await tester.pumpWidget(_app(const LoginPage()));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextFormField).first, 'owner@example.test');
    await tester.tap(find.byType(LanguageSelector));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Español').last);
    await tester.pumpAndSettle();
    expect(find.text('owner@example.test'), findsOneWidget);
    final context = tester.element(find.byType(LoginPage));
    expect(context.l10n.authLoginTitle,
        lookupAppLocalizations(const Locale('es')).authLoginTitle);
    expect(find.text(context.l10n.authLoginTitle), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
