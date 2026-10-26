import 'dart:ui' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vet_app_mobile/features/language/data/language_store.dart';
import 'package:vet_app_mobile/features/language/domain/app_language.dart';
import 'package:vet_app_mobile/features/settings/domain/unit_conversion.dart';
import 'package:vet_app_mobile/features/settings/domain/unit_system.dart';
import 'package:vet_app_mobile/l10n/date_formats.dart';
import 'package:vet_app_mobile/l10n/l10n.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    LanguageStore.instance.resetForTest();
    await LanguageStore.instance.choose(languageVariantById('de')!);
  });
  tearDown(LanguageStore.instance.resetForTest);

  test('German uses dd.MM.yyyy, decimal comma and metric units', () {
    final l10n = lookupAppLocalizations(const Locale('de'));
    expect(l10n.settingsNumericDatePattern, 'dd.MM.yyyy');
    expect(formatAppDate(DateTime(2026, 10, 5), l10n.settingsNumericDatePattern), '05.10.2026');
    expect(appDecimalSeparator(), ',');
    expect(decimalSeparator, ',');
    expect(defaultUnitsForLocale('DE'), UnitSystem.metric);
    expect(defaultUnitsForLocale('AT'), UnitSystem.metric);
    expect(defaultUnitsForLocale('CH'), UnitSystem.metric);
  });

  test('de-AT and de-CH share the German translation and the numeric date', () async {
    final at = languageVariantById('de-AT')!;
    final ch = languageVariantById('de-CH')!;
    expect([at.languageCode, ch.languageCode], ['de', 'de']);
    expect(at.flag, '🇦🇹');
    expect(ch.flag, '🇨🇭');
    for (final variant in [at, ch]) {
      await LanguageStore.instance.choose(variant);
      expect(LanguageStore.instance.variant.id, variant.id);
      expect(formatAppDate(DateTime(2026, 10, 5), 'dd.MM.yyyy'), '05.10.2026');
    }
    // Swiss usage writes the decimal point; Germany and Austria the comma.
    expect(appDecimalSeparator(), '.');
    await LanguageStore.instance.choose(at);
    expect(appDecimalSeparator(), ',');
  });

  test('a German phone is offered its own country variant', () {
    final available = availableLanguageVariants(const [Locale('it'), Locale('de')]);
    expect(suggestLanguageVariant(const Locale('de', 'AT'), available).id, 'de-AT');
    expect(suggestLanguageVariant(const Locale('de', 'CH'), available).id, 'de-CH');
    expect(suggestLanguageVariant(const Locale('de', 'DE'), available).id, 'de');
    expect(suggestLanguageVariant(const Locale('de', 'LU'), available).id, 'de');
  });

  test('German plurals use the =1 / other forms', () {
    final l10n = lookupAppLocalizations(const Locale('de'));
    expect(l10n.walksStatPauses(1), 'Pause');
    expect(l10n.walksStatPauses(3), 'Pausen');
    expect(l10n.petsAgeYears(1), '1 Jahr');
    expect(l10n.petsAgeYears(0), '0 Jahre');
    expect(l10n.petsAgeYears(5), '5 Jahre');
  });
}
