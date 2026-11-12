import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vet_app_mobile/features/language/data/language_store.dart';
import 'package:vet_app_mobile/features/language/domain/app_language.dart';
import 'package:vet_app_mobile/features/settings/domain/unit_system.dart';
import 'package:vet_app_mobile/l10n/date_formats.dart';
import 'package:vet_app_mobile/l10n/l10n.dart';
import 'package:vet_app_mobile/l10n/regional_defaults.dart';

void main() {
  final french =
      availableLanguageVariants([const Locale('fr'), const Locale('it')]);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LanguageStore.instance.resetForTest();
  });
  tearDown(LanguageStore.instance.resetForTest);

  test('the device country picks the French variant', () {
    expect(suggestLanguageVariant(const Locale('fr', 'FR'), french).id, 'fr');
    expect(
        suggestLanguageVariant(const Locale('fr', 'BE'), french).id, 'fr-BE');
    expect(
        suggestLanguageVariant(const Locale('fr', 'CH'), french).id, 'fr-CH');
    expect(suggestLanguageVariant(const Locale('fr', 'CA'), french).id, 'fr');
  });

  test(
      'French variants share one translation, metric units and a decimal comma',
      () async {
    for (final country in ['FR', 'BE', 'CH']) {
      expect(defaultUnitsForLocale(country), UnitSystem.metric);
    }
    LanguageStore.availableOverride = () => french;
    for (final id in ['fr', 'fr-BE', 'fr-CH']) {
      await LanguageStore.instance.choose(languageVariantById(id)!);
      expect(appL10n.commonCancel, 'Annuler');
      expect(appDecimalSeparator(), ',');
    }
  });

  test('numeric date and home country follow the variant', () async {
    LanguageStore.availableOverride = () => french;
    final day = DateTime(2021, 5, 5);
    await LanguageStore.instance.choose(languageVariantById('fr')!);
    expect(
        formatAppDate(day, appNumericDatePattern('dd/MM/yyyy')), '05/05/2021');
    expect(appHomeCountryDefault(), 'France');
    await LanguageStore.instance.choose(languageVariantById('fr-BE')!);
    expect(
        formatAppDate(day, appNumericDatePattern('dd/MM/yyyy')), '05/05/2021');
    expect(appHomeCountryDefault(), 'Belgique');
    await LanguageStore.instance.choose(languageVariantById('fr-CH')!);
    expect(
        formatAppDate(day, appNumericDatePattern('dd/MM/yyyy')), '05.05.2021');
    expect(appHomeCountryDefault(), 'Suisse');
  });
}
