import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vet_app_mobile/features/billing/domain/billing_models.dart';
import 'package:vet_app_mobile/features/language/data/language_store.dart';
import 'package:vet_app_mobile/features/language/domain/app_language.dart';
import 'package:vet_app_mobile/features/marketplace/presentation/marketplace_labels.dart';
import 'package:vet_app_mobile/features/settings/domain/unit_system.dart';
import 'package:vet_app_mobile/l10n/date_formats.dart';
import 'package:vet_app_mobile/l10n/l10n.dart';
import 'package:vet_app_mobile/l10n/regional_defaults.dart';
import 'package:vet_app_mobile/shared/formatters/date_input_formatter.dart';

/// One row per variant: the formats the owner of that country expects. A
/// regression here is a wrong currency, date order or country on screen.
class _Expect {
  const _Expect({
    required this.currency,
    required this.price,
    required this.numericDate,
    required this.hint,
    required this.country,
    required this.units,
  });

  final String currency;
  final String price; // 4.99 as the owner reads it
  final String numericDate; // 5 May 2021 typed/shown all-numeric... see test
  final String hint; // the "dd/mm/yyyy" hint in that language
  final String country;
  final UnitSystem units;
}

const _nbsp = ' ';
const _nnbsp = ' ';

const _expected = <String, _Expect>{
  'it': _Expect(
    currency: 'EUR',
    price: '4,99$_nbsp€',
    numericDate: '05/05/2021',
    hint: 'gg/mm/aaaa',
    country: 'Italia',
    units: UnitSystem.metric,
  ),
  'en-GB': _Expect(
    currency: 'GBP',
    price: '£4.99',
    numericDate: '05/05/2021',
    hint: 'dd/mm/yyyy',
    country: 'United Kingdom',
    units: UnitSystem.uk,
  ),
  'en-US': _Expect(
    currency: 'USD',
    price: r'$4.99',
    numericDate: '05/05/2021',
    hint: 'mm/dd/yyyy',
    country: 'United States',
    units: UnitSystem.us,
  ),
  'en-AU': _Expect(
    currency: 'AUD',
    price: r'A$4.99',
    numericDate: '05/05/2021',
    hint: 'dd/mm/yyyy',
    country: 'Australia',
    units: UnitSystem.metric,
  ),
  'de': _Expect(
    currency: 'EUR',
    price: '4,99$_nbsp€',
    numericDate: '05.05.2021',
    hint: 'TT.MM.JJJJ',
    country: 'Deutschland',
    units: UnitSystem.metric,
  ),
  'de-AT': _Expect(
    currency: 'EUR',
    price: '€${_nbsp}4,99',
    numericDate: '05.05.2021',
    hint: 'TT.MM.JJJJ',
    country: 'Österreich',
    units: UnitSystem.metric,
  ),
  'de-CH': _Expect(
    currency: 'CHF',
    price: 'CHF${_nbsp}4.99',
    numericDate: '05.05.2021',
    hint: 'TT.MM.JJJJ',
    country: 'Schweiz',
    units: UnitSystem.metric,
  ),
  'fr': _Expect(
    currency: 'EUR',
    price: '4,99$_nbsp€',
    numericDate: '05/05/2021',
    hint: 'jj/mm/aaaa',
    country: 'France',
    units: UnitSystem.metric,
  ),
  'fr-BE': _Expect(
    currency: 'EUR',
    price: '4,99$_nbsp€',
    numericDate: '05/05/2021',
    hint: 'jj/mm/aaaa',
    country: 'Belgique',
    units: UnitSystem.metric,
  ),
  'fr-CH': _Expect(
    currency: 'CHF',
    price: '4,99${_nbsp}CHF',
    numericDate: '05.05.2021',
    hint: 'jj.mm.aaaa',
    country: 'Suisse',
    units: UnitSystem.metric,
  ),
  'es': _Expect(
    currency: 'EUR',
    price: '4,99$_nbsp€',
    numericDate: '05/05/2021',
    hint: 'dd/mm/aaaa',
    country: 'España',
    units: UnitSystem.metric,
  ),
};

Future<void> _use(String id) => LanguageStore.instance.choose(languageVariantById(id)!);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LanguageStore.instance.resetForTest();
  });
  tearDown(LanguageStore.instance.resetForTest);

  test('the table covers every variant the picker offers', () {
    for (final variant in allLanguageVariants) {
      expect(_expected, contains(variant.id), reason: 'no expectations for ${variant.id}');
      expect(regionalFormatFor(variant.countryCode), isNotNull);
    }
  });

  group('per variant', () {
    for (final entry in _expected.entries) {
      final id = entry.key;
      final want = entry.value;

      test('$id: currency, price, date, typed date, hint, country, units', () async {
        await _use(id);
        expect(appCurrencyCode(), want.currency);
        expect(formatAppMoney(4.99), want.price);
        expect(formatPlanAmount(4.99), want.price);
        expect(listingPriceLabel(499), want.price);
        // 5 May 2021 is ambiguous day/month on purpose; 13 May tells the order.
        expect(formatAppDate(DateTime(2021, 5, 5), appNumericDatePattern()), want.numericDate);
        final typed = formatDateForInput(DateTime(2021, 5, 13));
        expect(typed, id == 'en-US' ? '05/13/2021' : startsWith('13'));
        expect(parseStrictDate(typed), DateTime(2021, 5, 13));
        expect(appDateInputText(appL10n.petsFormBirthDateHint), want.hint);
        expect(appHomeCountryDefault(), want.country);
        expect(appDefaultUnitSystem(), want.units);
        expect(appRegionalFormat().countryCode, languageVariantById(id)!.countryCode);
      });
    }
  });

  group('money', () {
    test('a price quoted in another currency keeps that currency', () async {
      await _use('it');
      expect(formatAppMoney(12.5, 'GBP'), '12,50$_nbsp£');
      await _use('en-GB');
      expect(formatAppMoney(12.5, 'EUR'), '€12.50');
      expect(formatAppMoney(12.5, 'CHF'), 'CHF12.50');
      expect(formatAppMoney(12.5, 'chf'), 'CHF12.50');
      expect(appCurrencySymbol('AUD'), r'A$');
      expect(appCurrencySymbol('JPY'), 'JPY');
    });

    test('cents and thousands separators follow the variant', () async {
      await _use('en-US');
      expect(formatAppMoneyCents(123450), r'$1,234.50');
      await _use('de-CH');
      expect(formatAppMoneyCents(123450), 'CHF${_nbsp}1’234.50');
      await _use('fr');
      expect(formatAppMoneyCents(123450), '1${_nnbsp}234,50$_nbsp€');
      expect(formatAppNumber(1234.5, decimals: 2), '1${_nnbsp}234,50');
    });

    test('a gift has no price in any variant', () async {
      for (final id in _expected.keys) {
        await _use(id);
        expect(listingPriceLabel(null), appL10n.marketplacePriceGift);
      }
    });
  });

  group('dates', () {
    test('US reads "May 5, 2021"; everybody else day first', () async {
      await _use('en-US');
      expect(formatAppDate(DateTime(2021, 5, 5), 'd MMM y'), 'May 5, 2021');
      expect(formatAppDate(DateTime(2021, 5, 5), 'd MMM'), 'May 5');
      expect(formatAppDate(DateTime(2021, 5, 5), 'd MMMM yyyy'), 'May 5, 2021');
      await _use('en-GB');
      expect(formatAppDate(DateTime(2021, 5, 5), 'd MMM y'), '5 May 2021');
      await _use('en-AU');
      expect(formatAppDate(DateTime(2021, 5, 5), 'd MMM y'), '5 May 2021');
    });

    test('typed dates: US month first, 13/05 is invalid there and valid elsewhere', () async {
      await _use('en-US');
      expect(parseStrictDate('05/13/2021'), DateTime(2021, 5, 13));
      expect(parseStrictDate('13/05/2021'), isNull);
      expect(parseStrictDate('05.13.2021'), isNull, reason: 'wrong separator');
      await _use('en-GB');
      expect(parseStrictDate('13/05/2021'), DateTime(2021, 5, 13));
      expect(parseStrictDate('05/13/2021'), isNull);
      await _use('de');
      expect(parseStrictDate('13.05.2021'), DateTime(2021, 5, 13));
      expect(parseStrictDate('13/05/2021'), isNull);
      expect(parseStrictDate('31.02.2021'), isNull);
    });

    test('the field formats digits in the variant order and follows a language change', () async {
      const formatter = DateInputFormatter();
      TextEditingValue type(String text) =>
          formatter.formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: text));
      await _use('en-US');
      expect(type('05132021').text, '05/13/2021');
      expect(type('0513').text, '05/13/');
      await _use('de-CH');
      expect(type('13052021').text, '13.05.2021');
      expect(type('1305').text, '13.05.');
      await _use('it');
      expect(type('13052021').text, '13/05/2021');
    });

    test('a pattern can be forced (tests, pickers)', () {
      expect(parseStrictDate('2021-05-13', pattern: 'yyyy-MM-dd'), DateTime(2021, 5, 13));
      expect(formatDateForInput(DateTime(2021, 5, 13), pattern: 'MM/dd/yyyy'), '05/13/2021');
      expect(DateInputFormatter.format('13052021', pattern: 'dd.MM.yyyy'), '13.05.2021');
    });

    test('hints and messages that quote the format are reordered, other text is left alone',
        () async {
      await _use('en-US');
      expect(appDateInputText('Invalid date (dd/mm/yyyy).'), 'Invalid date (mm/dd/yyyy).');
      expect(appDateInputText('No format here'), 'No format here');
      await _use('de-AT');
      expect(appDateInputText('Ungültiges Datum (TT/MM/JJJJ).'), 'Ungültiges Datum (TT.MM.JJJJ).');
    });

    test('every translation text quoting the format is rewritten for every variant', () async {
      for (final variant in allLanguageVariants) {
        await _use(variant.id);
        final l10n = appL10n;
        final order = appNumericDatePattern();
        for (final text in [
          l10n.petsFormBirthDateHint,
          l10n.remindersDatePlaceholder,
          l10n.petsFormBirthDateInvalid,
          l10n.remindersDateInvalid,
        ]) {
          final rewritten = appDateInputText(text);
          final separator = order.contains('.') ? '.' : '/';
          expect(rewritten, contains(separator), reason: '${variant.id}: $text');
          // The year is the last field in every country we support.
          expect(RegExp(r'(?:[A-Za-zÀ-ÿ]{1,4}[/.]){2}(a|y|j|J|A|Y)').hasMatch(rewritten), isTrue,
              reason: '${variant.id}: $rewritten');
        }
      }
    });
  });

  group('postal code and address', () {
    test('format per country', () {
      expect(isValidPostalCode('SW1A 1AA', 'GB'), isTrue);
      expect(isValidPostalCode('sw1a1aa', 'GB'), isTrue);
      expect(isValidPostalCode('90210', 'GB'), isFalse);
      expect(isValidPostalCode('90210', 'US'), isTrue);
      expect(isValidPostalCode('90210-1234', 'US'), isTrue);
      expect(isValidPostalCode('9021', 'US'), isFalse);
      expect(isValidPostalCode('2000', 'AU'), isTrue);
      expect(isValidPostalCode('20000', 'AU'), isFalse);
      expect(isValidPostalCode('10115', 'DE'), isTrue);
      expect(isValidPostalCode('1010', 'AT'), isTrue);
      expect(isValidPostalCode('8001', 'CH'), isTrue);
      expect(isValidPostalCode('75001', 'FR'), isTrue);
      expect(isValidPostalCode('1000', 'BE'), isTrue);
      expect(isValidPostalCode('28001', 'ES'), isTrue);
      expect(isValidPostalCode('00184', 'IT'), isTrue);
      expect(isValidPostalCode('', 'IT'), isFalse);
      expect(isValidPostalCode('whatever', 'LU'), isTrue, reason: 'unknown country: no opinion');
    });

    test('every example is valid for its own country', () {
      for (final code in supportedFormatCountries) {
        final format = regionalFormatFor(code)!;
        expect(isValidPostalCode(format.postalCodeExample, code), isTrue, reason: code);
      }
    });

    test('code-then-city on the continent, city-then-code in UK/US/AU', () {
      for (final code in ['IT', 'DE', 'AT', 'CH', 'FR', 'BE', 'ES']) {
        expect(regionalFormatFor(code)!.postalCodeBeforeCity, isTrue, reason: code);
      }
      for (final code in ['GB', 'US', 'AU']) {
        expect(regionalFormatFor(code)!.postalCodeBeforeCity, isFalse, reason: code);
      }
    });

    test('the map opens near the owner, not always in Rome', () async {
      await _use('en-GB');
      expect(appRegionalFormat().mapLatitude, closeTo(51.5, 0.1));
      await _use('es');
      expect(appRegionalFormat().mapLatitude, closeTo(40.4, 0.1));
    });
  });

  group('phone numbers', () {
    test('national numbers are read in the variant country', () async {
      await _use('en-GB');
      expect(normalizePhoneNumber('07911 123456'), '+447911123456');
      expect(normalizePhoneNumber('7911 123456'), '+447911123456');
      expect(formatPhoneNumber('07911123456'), '+44 7911 123456');
      await _use('en-US');
      expect(normalizePhoneNumber('(212) 555-0100'), '+12125550100');
      expect(normalizePhoneNumber('1 212 555 0100'), '+12125550100');
      expect(formatPhoneNumber('2125550100'), '+1 212 555 0100');
      await _use('en-AU');
      expect(normalizePhoneNumber('0412 345 678'), '+61412345678');
      expect(formatPhoneNumber('0412345678'), '+61 412 345 678');
      await _use('de-CH');
      expect(normalizePhoneNumber('079 123 45 67'), '+41791234567');
      expect(formatPhoneNumber('0791234567'), '+41 79 123 45 67');
      await _use('fr');
      expect(normalizePhoneNumber('06 12 34 56 78'), '+33612345678');
      expect(formatPhoneNumber('0612345678'), '+33 6 12 34 56 78');
      await _use('es');
      expect(normalizePhoneNumber('612 345 678'), '+34612345678');
      expect(formatPhoneNumber('612345678'), '+34 612 345 678');
      await _use('it');
      expect(normalizePhoneNumber('345 123 4567'), '+393451234567');
      expect(formatPhoneNumber('3451234567'), '+39 345 123 4567');
    });

    test('international forms are accepted anywhere, from any variant', () async {
      await _use('it');
      expect(normalizePhoneNumber('+44 7911 123456'), '+447911123456');
      expect(normalizePhoneNumber('0044 7911 123456'), '+447911123456');
      expect(formatPhoneNumber('+447911123456'), '+44 7911 123456');
      expect(normalizePhoneNumber('+81 90 1234 5678'), '+819012345678',
          reason: 'country outside the table: kept as typed');
    });

    test('wrong lengths and junk are rejected', () async {
      await _use('en-GB');
      expect(normalizePhoneNumber(''), isNull);
      expect(normalizePhoneNumber('0791'), isNull);
      expect(normalizePhoneNumber('07911 12345678901'), isNull);
      expect(normalizePhoneNumber('call me'), isNull);
      expect(normalizePhoneNumber('+44 12'), isNull);
      expect(formatPhoneNumber('call me'), 'call me');
      await _use('en-US');
      expect(normalizePhoneNumber('212 555 010'), isNull);
    });
  });

  group('units by country', () {
    test('only the UK and the US leave metric', () {
      expect(appDefaultUnitSystem('GB'), UnitSystem.uk);
      expect(appDefaultUnitSystem('US'), UnitSystem.us);
      for (final code in ['IT', 'AU', 'DE', 'AT', 'CH', 'FR', 'BE', 'ES']) {
        expect(appDefaultUnitSystem(code), UnitSystem.metric, reason: code);
      }
    });
  });

  test('a country outside the table falls back to the translation', () {
    AppLocaleHolder.current = const Locale('fr', 'LU');
    expect(appNumericDatePattern('dd/MM/yyyy'), 'dd/MM/yyyy');
    expect(appNumericDatePattern(), 'dd/MM/yyyy');
    expect(appCurrencyCode(), 'EUR', reason: 'falls back to the Italian row');
  });

  test('a plain language picks its main country', () {
    AppLocaleHolder.current = const Locale('en');
    expect(appCountryCode(), 'GB');
    AppLocaleHolder.current = const Locale('es');
    expect(appCountryCode(), 'ES');
  });

  test('no screen hard-codes a currency symbol or a date order', () {
    // Everything goes through regional_defaults.dart; this keeps it that way.
    final offenders = <String>[];
    final symbol = RegExp(r'''['"][^'"\n]*[€£][^'"\n]*['"]|symbol:\s*['"]''');
    final dateOrder = RegExp(r'''['"](dd[/.]MM[/.]yyyy|MM/dd/yyyy)['"]''');
    for (final file in Directory('lib').listSync(recursive: true).whereType<File>()) {
      final path = file.path.replaceAll(r'\', '/');
      if (!path.endsWith('.dart') ||
          path.contains('/l10n/app_localizations') ||
          path.endsWith('/l10n/regional_defaults.dart')) {
        continue;
      }
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trimLeft();
        if (line.startsWith('//')) continue;
        if (symbol.hasMatch(line) || dateOrder.hasMatch(line)) {
          offenders.add('$path:${i + 1}: $line');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
