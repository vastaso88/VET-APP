import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/auth/presentation/widgets/phone_number_field.dart';
import 'package:vet_app_mobile/l10n/l10n.dart';
import 'package:vet_app_mobile/l10n/regional_defaults.dart';

Widget _app(PhoneInputController controller, {Locale locale = const Locale('it')}) {
  AppLocaleHolder.current = locale;
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: PhoneNumberField(
            controller: controller,
            label: 'Telefono',
            helperText: 'Facoltativo',
          ),
        ),
      ),
    ),
  );
}

void main() {
  tearDown(() => AppLocaleHolder.current = const Locale('it'));

  group('PhoneInputController', () {
    test('an empty field is valid and gives no number', () {
      final controller = PhoneInputController();
      expect(controller.isValid, isTrue);
      expect(controller.e164, isNull);
    });

    test('a national number gets the prefix of the selected country (E.164)', () {
      final controller = PhoneInputController(defaultCountry: 'IT');
      controller.text.text = '333 1234567';
      expect(controller.e164, '+393331234567');

      controller.country = 'GB';
      controller.text.text = '07911 123456';
      expect(controller.e164, '+447911123456');

      controller.country = 'US';
      controller.text.text = '(555) 123-4567';
      expect(controller.e164, '+15551234567');
    });

    test('a number that is too short for the country is not valid', () {
      final controller = PhoneInputController(defaultCountry: 'DE');
      controller.text.text = '12';
      expect(controller.isValid, isFalse);
      expect(controller.e164, isNull);
    });

    test('typing an international number moves the prefix to its country', () {
      final controller = PhoneInputController(defaultCountry: 'IT');
      controller.text.text = '+44 7911 123456';
      expect(controller.country, 'GB');
      expect(controller.e164, '+447911123456');
    });

    test('a stored number is split into country and national digits', () {
      final controller = PhoneInputController(initialStored: '+447911123456');
      expect(controller.country, 'GB');
      expect(controller.text.text, '7911 123456');
      expect(controller.e164, '+447911123456');
    });

    test('an old free-text value is kept as typed instead of being lost', () {
      final controller = PhoneInputController(initialStored: 'ufficio 06 123');
      expect(controller.text.text, 'ufficio 06 123');
      expect(controller.isValid, isFalse);
    });
  });

  group('country flags and list', () {
    test('flags are built from the country code', () {
      expect(countryFlagEmoji('IT'), '\u{1F1EE}\u{1F1F9}');
      expect(countryFlagEmoji('gb'), '\u{1F1EC}\u{1F1E7}');
      expect(countryFlagEmoji('XYZ'), '');
    });

    test('the variant country comes first, then the others by name', () {
      AppLocaleHolder.current = const Locale('de', 'AT');
      final codes = [for (final format in phoneCountriesForPicker()) format.countryCode];
      expect(codes.first, 'AT');
      expect(codes.toSet(), supportedFormatCountries.toSet());
    });
  });

  testWidgets('the picker lists flag, dial code and country name, and applies the choice',
      (tester) async {
    final controller = PhoneInputController(defaultCountry: 'IT');
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller));

    expect(find.text('+39'), findsOneWidget);
    await tester.tap(find.text('+39'));
    await tester.pumpAndSettle();

    expect(find.text('Scegli il prefisso'), findsOneWidget);
    expect(find.text('Regno Unito'), findsOneWidget);
    expect(find.text('+44'), findsOneWidget);
    expect(find.text(countryFlagEmoji('GB')), findsOneWidget);

    await tester.tap(find.text('Regno Unito'));
    await tester.pumpAndSettle();

    expect(controller.country, 'GB');
    expect(find.text('+44'), findsOneWidget);
  });

  testWidgets('the picker fits a narrow phone in German with enlarged system text', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final controller = PhoneInputController(defaultCountry: 'DE');
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller, locale: const Locale('de')));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('+49'));
    await tester.pumpAndSettle();

    expect(find.text('Ländervorwahl wählen'), findsOneWidget);
    // At 2x text the list is longer than the screen: scroll to the longest name.
    await tester.scrollUntilVisible(
      find.text('Vereinigtes Königreich'),
      100,
      scrollable: find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)),
    );
    expect(find.text('Vereinigtes Königreich'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
