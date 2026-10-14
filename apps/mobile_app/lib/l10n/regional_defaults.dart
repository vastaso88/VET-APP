import 'l10n.dart';

/// Per-country adjustments on top of a language's translation (the ARB file
/// is shared by all variants of a language, e.g. fr-FR / fr-BE / fr-CH).

/// Numeric date pattern: the translation's own pattern (`dd/MM/yyyy`), except
/// in Switzerland, which writes `dd.MM.yyyy`. Text-entry fields still use the
/// translation's `dd/mm/yyyy` hint and parser.
String appNumericDatePattern(String translationPattern) =>
    AppLocaleHolder.current.countryCode?.toUpperCase() == 'CH'
        ? 'dd.MM.yyyy'
        : translationPattern;

/// Country name pre-filled in the home-address form: the chosen variant's
/// country when the translation covers several (French: France / Belgique /
/// Suisse; German: Deutschland / Österreich / Schweiz), else the translation's
/// `settingsHomeCountryDefault`.
String appHomeCountryDefault() {
  final locale = AppLocaleHolder.current;
  if (locale.languageCode == 'fr') {
    switch (locale.countryCode?.toUpperCase()) {
      case 'BE':
        return 'Belgique';
      case 'CH':
        return 'Suisse';
    }
  }
  if (locale.languageCode == 'de') {
    switch (locale.countryCode?.toUpperCase()) {
      case 'AT':
        return 'Österreich';
      case 'CH':
        return 'Schweiz';
    }
  }
  return appL10n.settingsHomeCountryDefault;
}
