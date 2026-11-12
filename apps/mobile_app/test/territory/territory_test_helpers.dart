import 'package:shared_preferences/shared_preferences.dart';
import 'package:vet_app_mobile/features/language/data/account_language_store.dart';
import 'package:vet_app_mobile/features/language/data/language_store.dart';
import 'package:vet_app_mobile/features/language/domain/app_language.dart';
import 'package:vet_app_mobile/features/settings/data/unit_settings_store.dart';
import 'package:vet_app_mobile/features/settings/domain/unit_system.dart';

class _NoAccountLanguageStore implements AccountLanguageStore {
  const _NoAccountLanguageStore();

  @override
  Future<String?> read() async => null;

  @override
  Future<void> write(String languageCode, String variantId) async {}
}

/// Makes the app behave as if the owner picked the language variant [id]
/// ('it', 'en-GB', 'en-US', 'en-AU', 'es'...): language, country, units.
/// Pair with [resetTerritoryForTest] in `tearDown`.
Future<void> useLanguageVariant(String id) async {
  SharedPreferences.setMockInitialValues({});
  LanguageStore.instance.accountStore = const _NoAccountLanguageStore();
  await LanguageStore.instance.choose(languageVariantById(id)!);
}

void resetTerritoryForTest() {
  LanguageStore.instance.resetForTest();
  UnitSettingsStore.instance.applyLocaleDefault(UnitSystem.metric);
}
