import 'dart:ui';

/// One entry of the language picker: a flag, the name in its own language and
/// the locale it selects.
///
/// Several variants can share one translation (all three English variants use
/// the "en" ARB file): the country is what differs, and it decides the
/// default measurement units and number/date formats (see
/// `defaultUnitsForLocale`).
class AppLanguageVariant {
  const AppLanguageVariant({
    required this.id,
    required this.languageCode,
    required this.countryCode,
    required this.flag,
    required this.nativeName,
  });

  /// Stable id saved on the phone: 'it', 'en-GB', 'en-US', 'en-AU', 'de', ...
  final String id;

  /// Language of the translation: it, en, de, fr, es.
  final String languageCode;

  /// Country that picks units and formats; null = none implied.
  final String? countryCode;
  final String flag;

  /// The language's name in that language: never translated.
  final String nativeName;

  Locale get locale => Locale(languageCode, countryCode);
}

/// Every variant the product plans to offer, in picker order. A variant is
/// only *offered* when its language has a translation (an `app_xx.arb`), see
/// [availableLanguageVariants]. To add a variant of an existing language,
/// add a row here; to add a language, also add its ARB (docs/i18n/README.md).
const allLanguageVariants = <AppLanguageVariant>[
  AppLanguageVariant(
    id: 'it',
    languageCode: 'it',
    countryCode: 'IT',
    flag: '🇮🇹',
    nativeName: 'Italiano',
  ),
  AppLanguageVariant(
    id: 'en-GB',
    languageCode: 'en',
    countryCode: 'GB',
    flag: '🇬🇧',
    nativeName: 'English (UK)',
  ),
  AppLanguageVariant(
    id: 'en-US',
    languageCode: 'en',
    countryCode: 'US',
    flag: '🇺🇸',
    nativeName: 'English (US)',
  ),
  AppLanguageVariant(
    id: 'en-AU',
    languageCode: 'en',
    countryCode: 'AU',
    flag: '🇦🇺',
    nativeName: 'English (Australia)',
  ),
  AppLanguageVariant(
    id: 'de',
    languageCode: 'de',
    countryCode: 'DE',
    flag: '🇩🇪',
    nativeName: 'Deutsch',
  ),
  AppLanguageVariant(
    id: 'fr',
    languageCode: 'fr',
    countryCode: 'FR',
    flag: '🇫🇷',
    nativeName: 'Français',
  ),
  AppLanguageVariant(
    id: 'fr-BE',
    languageCode: 'fr',
    countryCode: 'BE',
    flag: '🇧🇪',
    nativeName: 'Français (Belgique)',
  ),
  AppLanguageVariant(
    id: 'fr-CH',
    languageCode: 'fr',
    countryCode: 'CH',
    flag: '🇨🇭',
    nativeName: 'Français (Suisse)',
  ),
  AppLanguageVariant(
    id: 'es',
    languageCode: 'es',
    countryCode: 'ES',
    flag: '🇪🇸',
    nativeName: 'Español',
  ),
];

/// The source language: always available, used when nothing else matches.
const sourceLanguageVariantId = 'it';

AppLanguageVariant? languageVariantById(String? id) {
  for (final variant in allLanguageVariants) {
    if (variant.id == id) return variant;
  }
  return null;
}

/// Variants whose language has a translation in [supported] (normally
/// `AppLocalizations.supportedLocales`, i.e. the ARB files that exist).
List<AppLanguageVariant> availableLanguageVariants(Iterable<Locale> supported) {
  final languages = supported.map((locale) => locale.languageCode).toSet();
  return [
    for (final variant in allLanguageVariants)
      if (languages.contains(variant.languageCode)) variant,
  ];
}

/// The variant to propose from the phone's language/country: an exact match,
/// else the first available variant of the same language (English from
/// Ireland → UK, from New Zealand → Australia, anywhere else → US), else
/// Italian.
AppLanguageVariant suggestLanguageVariant(
  Locale device,
  List<AppLanguageVariant> available,
) {
  final sameLanguage =
      available.where((v) => v.languageCode == device.languageCode).toList();
  if (sameLanguage.isEmpty) {
    return available.firstWhere(
      (v) => v.id == sourceLanguageVariantId,
      orElse: () => available.first,
    );
  }
  final country = device.countryCode?.toUpperCase();
  for (final variant in sameLanguage) {
    if (variant.countryCode == country) return variant;
  }
  if (device.languageCode == 'en') {
    const mapped = {'IE': 'GB', 'NZ': 'AU'};
    final target = mapped[country] ?? 'US';
    for (final variant in sameLanguage) {
      if (variant.countryCode == target) return variant;
    }
  }
  return sameLanguage.first;
}
