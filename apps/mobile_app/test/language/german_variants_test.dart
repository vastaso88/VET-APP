import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vet_app_mobile/features/language/data/language_store.dart';
import 'package:vet_app_mobile/features/language/domain/app_language.dart';
import 'package:vet_app_mobile/l10n/date_formats.dart';
import 'package:vet_app_mobile/l10n/l10n.dart';
import 'package:vet_app_mobile/l10n/regional_defaults.dart';

void main() {
  final german =
      availableLanguageVariants([const Locale('de'), const Locale('it')]);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LanguageStore.instance.resetForTest();
  });
  tearDown(LanguageStore.instance.resetForTest);

  test('the device country picks the German variant', () {
    expect(suggestLanguageVariant(const Locale('de', 'DE'), german).id, 'de');
    expect(
        suggestLanguageVariant(const Locale('de', 'AT'), german).id, 'de-AT');
    expect(
        suggestLanguageVariant(const Locale('de', 'CH'), german).id, 'de-CH');
  });

  test('German variants share one translation and pre-fill their own country',
      () async {
    LanguageStore.availableOverride = () => german;
    final day = DateTime(2021, 5, 5);
    const expectedCountry = {
      'de': 'Deutschland',
      'de-AT': 'Österreich',
      'de-CH': 'Schweiz',
    };
    for (final entry in expectedCountry.entries) {
      await LanguageStore.instance.choose(languageVariantById(entry.key)!);
      expect(appL10n.commonCancel, 'Abbrechen');
      expect(appHomeCountryDefault(), entry.value);
      expect(
          formatAppDate(
              day, appNumericDatePattern(appL10n.settingsNumericDatePattern)),
          '05.05.2021');
    }
  });
}
