import 'package:intl/intl.dart';

import '../features/settings/domain/unit_system.dart';
import 'date_formats.dart' show appIntlLocale;
import 'l10n.dart';

/// Per-country formats on top of a language's translation.
///
/// The ARB file is shared by every variant of a language (en-GB / en-US /
/// en-AU, de / de-AT / de-CH, fr / fr-BE / fr-CH); what differs by country
/// lives here, in one table: currency, numeric date, postal code and address
/// order, phone numbers, default units. Everything is read from the variant the
/// owner chose ([AppLocaleHolder.current]), so a runtime language change is
/// enough to move all of it.
///
/// Public helpers for other features: [formatAppMoney] / [formatAppMoneyCents]
/// and [appCurrencyCode] (prices), [appNumericDatePattern] (dates, with
/// `shared/formatters/date_input_formatter.dart` for typed dates),
/// [formatAppNumber], [appRegionalFormat] (postal code, phone, address order),
/// [appHomeCountryDefault].

// ── The table ──────────────────────────────────────────────────────────────

/// How one country writes money, dates, addresses and phone numbers.
class RegionalFormat {
  const RegionalFormat({
    required this.countryCode,
    required this.mapLatitude,
    required this.mapLongitude,
    required this.currencyCode,
    required this.numericDatePattern,
    required this.postalCodePattern,
    required this.postalCodeExample,
    required this.postalCodeBeforeCity,
    required this.dialCode,
    required this.phoneTrunkPrefix,
    required this.phoneMinDigits,
    required this.phoneMaxDigits,
    required this.phoneGroups,
    required this.phoneHint,
    this.postalCodeNumeric = true,
  });

  /// ISO 3166-1 alpha-2: IT, GB, US, AU, DE, AT, CH, FR, BE, ES.
  final String countryCode;

  /// Where a map picker opens when the owner has no position yet: the
  /// country's best-known city (Rome, London, New York, Sydney, Berlin, ...).
  final double mapLatitude;
  final double mapLongitude;

  /// ISO 4217: EUR, GBP, USD, AUD, CHF.
  final String currencyCode;

  /// All-numeric date in this country (`dd/MM/yyyy`, `MM/dd/yyyy`, `dd.MM.yyyy`).
  final String numericDatePattern;

  final RegExp postalCodePattern;
  final String postalCodeExample;

  /// Written "10115 Berlin" (true) or "London SW1A 1AA" (false).
  final bool postalCodeBeforeCity;

  /// False for alphanumeric codes (UK), which want a text keyboard.
  final bool postalCodeNumeric;

  /// International dial code without "+": 39, 44, 1, 61, 49, 43, 41, 33, 32, 34.
  final String dialCode;

  /// Digit(s) dialled before the national number at home ("0"), dropped in
  /// the international form. Empty where there is none (Italy keeps its 0
  /// as part of the number).
  final String phoneTrunkPrefix;

  /// Length range of the national number, trunk prefix excluded.
  final int phoneMinDigits;
  final int phoneMaxDigits;

  /// How the national number is split for display; leftovers form the last group.
  final List<int> phoneGroups;

  /// Shape of a number, for a hint: letters, never a real number.
  final String phoneHint;
}

final _formats = <String, RegionalFormat>{
  'IT': RegionalFormat(
    countryCode: 'IT',
    mapLatitude: 41.9028,
    mapLongitude: 12.4964,
    currencyCode: 'EUR',
    numericDatePattern: 'dd/MM/yyyy',
    postalCodePattern: RegExp(r'^\d{5}$'),
    postalCodeExample: '00184',
    postalCodeBeforeCity: true,
    dialCode: '39',
    phoneTrunkPrefix: '',
    phoneMinDigits: 6,
    phoneMaxDigits: 11,
    phoneGroups: const [3, 3, 4],
    phoneHint: '+39 3xx xxx xxxx',
  ),
  'GB': RegionalFormat(
    countryCode: 'GB',
    mapLatitude: 51.5074,
    mapLongitude: -0.1278,
    currencyCode: 'GBP',
    numericDatePattern: 'dd/MM/yyyy',
    postalCodePattern: RegExp(r'^[A-Z]{1,2}\d[A-Z\d]? ?\d[A-Z]{2}$', caseSensitive: false),
    postalCodeExample: 'SW1A 1AA',
    postalCodeBeforeCity: false,
    postalCodeNumeric: false,
    dialCode: '44',
    phoneTrunkPrefix: '0',
    phoneMinDigits: 9,
    phoneMaxDigits: 10,
    phoneGroups: const [4, 6],
    phoneHint: '+44 7xxx xxxxxx',
  ),
  'US': RegionalFormat(
    countryCode: 'US',
    mapLatitude: 40.7128,
    mapLongitude: -74.006,
    currencyCode: 'USD',
    numericDatePattern: 'MM/dd/yyyy',
    postalCodePattern: RegExp(r'^\d{5}(-\d{4})?$'),
    postalCodeExample: '10001',
    postalCodeBeforeCity: false,
    dialCode: '1',
    phoneTrunkPrefix: '1',
    phoneMinDigits: 10,
    phoneMaxDigits: 10,
    phoneGroups: const [3, 3, 4],
    phoneHint: '+1 xxx xxx xxxx',
  ),
  'AU': RegionalFormat(
    countryCode: 'AU',
    mapLatitude: -33.8688,
    mapLongitude: 151.2093,
    currencyCode: 'AUD',
    numericDatePattern: 'dd/MM/yyyy',
    postalCodePattern: RegExp(r'^\d{4}$'),
    postalCodeExample: '2000',
    postalCodeBeforeCity: false,
    dialCode: '61',
    phoneTrunkPrefix: '0',
    phoneMinDigits: 9,
    phoneMaxDigits: 9,
    phoneGroups: const [3, 3, 3],
    phoneHint: '+61 4xx xxx xxx',
  ),
  'DE': RegionalFormat(
    countryCode: 'DE',
    mapLatitude: 52.52,
    mapLongitude: 13.405,
    currencyCode: 'EUR',
    numericDatePattern: 'dd.MM.yyyy',
    postalCodePattern: RegExp(r'^\d{5}$'),
    postalCodeExample: '10115',
    postalCodeBeforeCity: true,
    dialCode: '49',
    phoneTrunkPrefix: '0',
    phoneMinDigits: 7,
    phoneMaxDigits: 13,
    phoneGroups: const [4, 3, 4],
    phoneHint: '+49 1xx xxxxxxx',
  ),
  'AT': RegionalFormat(
    countryCode: 'AT',
    mapLatitude: 48.2082,
    mapLongitude: 16.3738,
    currencyCode: 'EUR',
    numericDatePattern: 'dd.MM.yyyy',
    postalCodePattern: RegExp(r'^\d{4}$'),
    postalCodeExample: '1010',
    postalCodeBeforeCity: true,
    dialCode: '43',
    phoneTrunkPrefix: '0',
    phoneMinDigits: 7,
    phoneMaxDigits: 13,
    phoneGroups: const [3, 3, 4],
    phoneHint: '+43 6xx xxxxxxx',
  ),
  'CH': RegionalFormat(
    countryCode: 'CH',
    mapLatitude: 46.948,
    mapLongitude: 7.4474,
    currencyCode: 'CHF',
    numericDatePattern: 'dd.MM.yyyy',
    postalCodePattern: RegExp(r'^\d{4}$'),
    postalCodeExample: '8001',
    postalCodeBeforeCity: true,
    dialCode: '41',
    phoneTrunkPrefix: '0',
    phoneMinDigits: 9,
    phoneMaxDigits: 9,
    phoneGroups: const [2, 3, 2, 2],
    phoneHint: '+41 7x xxx xx xx',
  ),
  'FR': RegionalFormat(
    countryCode: 'FR',
    mapLatitude: 48.8566,
    mapLongitude: 2.3522,
    currencyCode: 'EUR',
    numericDatePattern: 'dd/MM/yyyy',
    postalCodePattern: RegExp(r'^\d{5}$'),
    postalCodeExample: '75001',
    postalCodeBeforeCity: true,
    dialCode: '33',
    phoneTrunkPrefix: '0',
    phoneMinDigits: 9,
    phoneMaxDigits: 9,
    phoneGroups: const [1, 2, 2, 2, 2],
    phoneHint: '+33 6 xx xx xx xx',
  ),
  'BE': RegionalFormat(
    countryCode: 'BE',
    mapLatitude: 50.8503,
    mapLongitude: 4.3517,
    currencyCode: 'EUR',
    numericDatePattern: 'dd/MM/yyyy',
    postalCodePattern: RegExp(r'^\d{4}$'),
    postalCodeExample: '1000',
    postalCodeBeforeCity: true,
    dialCode: '32',
    phoneTrunkPrefix: '0',
    phoneMinDigits: 8,
    phoneMaxDigits: 9,
    phoneGroups: const [3, 2, 2, 2],
    phoneHint: '+32 4xx xx xx xx',
  ),
  'ES': RegionalFormat(
    countryCode: 'ES',
    mapLatitude: 40.4168,
    mapLongitude: -3.7038,
    currencyCode: 'EUR',
    numericDatePattern: 'dd/MM/yyyy',
    postalCodePattern: RegExp(r'^\d{5}$'),
    postalCodeExample: '28001',
    postalCodeBeforeCity: true,
    dialCode: '34',
    phoneTrunkPrefix: '',
    phoneMinDigits: 9,
    phoneMaxDigits: 9,
    phoneGroups: const [3, 3, 3],
    phoneHint: '+34 6xx xxx xxx',
  ),
};

/// Country assumed for a language that carries none (a plain `Locale('en')`).
const _languageDefaultCountry = {
  'it': 'IT',
  'en': 'GB',
  'de': 'DE',
  'fr': 'FR',
  'es': 'ES',
};

/// ISO code of the country the chosen variant stands for ("GB", "CH", ...).
String appCountryCode() {
  final locale = AppLocaleHolder.current;
  final country = locale.countryCode?.toUpperCase();
  if (country != null && country.isNotEmpty) return country;
  return _languageDefaultCountry[locale.languageCode] ?? 'IT';
}

/// The format of [countryCode], or null for a country outside the table.
RegionalFormat? regionalFormatFor(String? countryCode) => _formats[countryCode?.toUpperCase()];

/// The format of the chosen variant's country; Italy's when that is unknown.
RegionalFormat appRegionalFormat() => regionalFormatFor(appCountryCode()) ?? _formats['IT']!;

/// Countries the table knows (the ones the app has a language variant for).
Iterable<String> get supportedFormatCountries => _formats.keys;

// ── Money ──────────────────────────────────────────────────────────────────

const _currencySymbols = <String, String>{
  'EUR': '€',
  'GBP': '£',
  'USD': r'$',
  'AUD': r'A$',
  'CHF': 'CHF',
};

/// Currency of the chosen variant's country: EUR, GBP, USD, AUD, CHF.
String appCurrencyCode() => appRegionalFormat().currencyCode;

/// "£", "$", "A$", "€", "CHF"; the ISO code itself for any other currency.
String appCurrencySymbol([String? currencyCode]) {
  final code = (currencyCode ?? appCurrencyCode()).toUpperCase();
  return _currencySymbols[code] ?? code;
}

/// An amount as the owner of this variant writes it: symbol side, decimal and
/// thousands separators come from the variant's own number format
/// ("£4.99", "$4.99", "A$4.99", "4,99 €", "CHF 4.99", "4.99 CHF" in fr-CH).
/// [currencyCode] defaults to the variant's own currency; pass another one to
/// show a price in the currency it is quoted in (a listing in pounds read from
/// a euro phone) without converting it.
String formatAppMoney(num amount, [String? currencyCode]) {
  final code = (currencyCode ?? appCurrencyCode()).toUpperCase();
  return NumberFormat.currency(
    locale: appIntlLocale,
    name: code,
    symbol: appCurrencySymbol(code),
    decimalDigits: 2,
  ).format(amount);
}

/// [formatAppMoney] for a price stored in minor units (cents, pence).
String formatAppMoneyCents(int cents, [String? currencyCode]) =>
    formatAppMoney(cents / 100, currencyCode);

// ── Numbers and units ──────────────────────────────────────────────────────

/// A plain number with the variant's separators ("1,234.5", "1.234,5",
/// "1’234.5"). [decimals] fixes the digits after the separator.
String formatAppNumber(num value, {int? decimals}) {
  final format = NumberFormat.decimalPattern(appIntlLocale);
  if (decimals != null) {
    format
      ..minimumFractionDigits = decimals
      ..maximumFractionDigits = decimals;
  }
  return format.format(value);
}

/// Measurement system the variant starts from (the owner can change it in
/// Settings): metric everywhere except the UK (miles, pounds, °C) and the
/// US (miles, pounds, °F, US gallons). Australia is metric.
UnitSystem appDefaultUnitSystem([String? countryCode]) =>
    defaultUnitsForLocale(countryCode ?? appCountryCode());

// ── Dates ──────────────────────────────────────────────────────────────────

/// Numeric date pattern of the chosen variant's country: `dd/MM/yyyy`,
/// `MM/dd/yyyy` (US), `dd.MM.yyyy` (Germany, Austria, Switzerland).
///
/// [translationPattern] (the ARB's `settingsNumericDatePattern`) is only the
/// fallback for a country outside the table.
String appNumericDatePattern([String? translationPattern]) =>
    regionalFormatFor(appCountryCode())?.numericDatePattern ??
    translationPattern ??
    'dd/MM/yyyy';

final _hintFormat = RegExp(r'(\p{L}{1,4})([/.\-])(\p{L}{1,4})\2(\p{L}{1,4})', unicode: true);

/// Rewrites the translation's `dd/mm/yyyy`-style date format ("gg/mm/aaaa",
/// "TT/MM/JJJJ", "jj/mm/aaaa", ...) so that fields come in this country's
/// order with its separator ("mm/dd/yyyy", "TT.MM.JJJJ"). The ARB texts are
/// all day-month-year; anything not shaped like that is returned as is.
///
/// Works on hints (`dd/mm/yyyy`) and on messages that quote one
/// ("Invalid date (dd/mm/yyyy).").
String appDateInputText(String translated) => translated.replaceAllMapped(_hintFormat, (match) {
      final day = match.group(1)!;
      final month = match.group(3)!;
      final year = match.group(4)!;
      final pattern = appNumericDatePattern();
      final separator = pattern.contains('.')
          ? '.'
          : pattern.contains('-')
              ? '-'
              : '/';
      final parts = <String>[];
      for (final field in pattern.split(RegExp(r'[^A-Za-z]+'))) {
        parts.add(switch (field[0]) {
          'd' => day,
          'M' => month,
          _ => year,
        });
      }
      return parts.join(separator);
    });

/// `d MMM y` and friends read "May 5, 2021" in the US; every other country
/// keeps the day first. Used by `appDateFormat`.
String appLocalizeDatePattern(String pattern) {
  if (appCountryCode() != 'US' || AppLocaleHolder.current.languageCode != 'en') return pattern;
  final match = RegExp(r'^(d{1,2}) (M{3,4})(?: (y+))?$').firstMatch(pattern);
  if (match == null) return pattern;
  final year = match.group(3);
  return year == null ? '${match.group(2)} ${match.group(1)}' : '${match.group(2)} ${match.group(1)}, $year';
}

// ── Country names and the home-address default ─────────────────────────────

const _countryNames = <String, Map<String, String>>{
  'it': {
    'IT': 'Italia', 'GB': 'Regno Unito', 'US': 'Stati Uniti', 'AU': 'Australia',
    'DE': 'Germania', 'AT': 'Austria', 'CH': 'Svizzera', 'FR': 'Francia',
    'BE': 'Belgio', 'ES': 'Spagna',
  },
  'en': {
    'IT': 'Italy', 'GB': 'United Kingdom', 'US': 'United States', 'AU': 'Australia',
    'DE': 'Germany', 'AT': 'Austria', 'CH': 'Switzerland', 'FR': 'France',
    'BE': 'Belgium', 'ES': 'Spain',
  },
  'de': {
    'IT': 'Italien', 'GB': 'Vereinigtes Königreich', 'US': 'Vereinigte Staaten',
    'AU': 'Australien', 'DE': 'Deutschland', 'AT': 'Österreich', 'CH': 'Schweiz',
    'FR': 'Frankreich', 'BE': 'Belgien', 'ES': 'Spanien',
  },
  'fr': {
    'IT': 'Italie', 'GB': 'Royaume-Uni', 'US': 'États-Unis', 'AU': 'Australie',
    'DE': 'Allemagne', 'AT': 'Autriche', 'CH': 'Suisse', 'FR': 'France',
    'BE': 'Belgique', 'ES': 'Espagne',
  },
  'es': {
    'IT': 'Italia', 'GB': 'Reino Unido', 'US': 'Estados Unidos', 'AU': 'Australia',
    'DE': 'Alemania', 'AT': 'Austria', 'CH': 'Suiza', 'FR': 'Francia',
    'BE': 'Bélgica', 'ES': 'España',
  },
};

/// [countryCode]'s name in the app language ("Regno Unito", "Suiza"), or null
/// for a country the table does not name.
String? appCountryName([String? countryCode]) =>
    _countryNames[AppLocaleHolder.current.languageCode]?[(countryCode ?? appCountryCode()).toUpperCase()];

/// Country pre-filled in the home-address form: the chosen variant's country
/// (the variant itself is proposed from the phone's country at first run), in
/// the app language; the translation's `settingsHomeCountryDefault` when the
/// variant has no named country. The owner can always edit it.
String appHomeCountryDefault() => appCountryName() ?? appL10n.settingsHomeCountryDefault;

// ── Postal code ────────────────────────────────────────────────────────────

/// Whether [text] is a plausible postal code for [countryCode] (default: the
/// variant's country). An unknown country accepts anything non-empty.
bool isValidPostalCode(String text, [String? countryCode]) {
  final value = text.trim();
  if (value.isEmpty) return false;
  final format = countryCode == null ? appRegionalFormat() : regionalFormatFor(countryCode);
  return format == null || format.postalCodePattern.hasMatch(value);
}

// ── Phone ──────────────────────────────────────────────────────────────────

/// A phone number in international form ("+447911123456"), or null when it
/// cannot be one. Accepts "+44…", "0044…" and national numbers, which are
/// read as belonging to [defaultCountry] (default: the variant's country),
/// with or without the trunk prefix ("07911…" and "7911…" are the same).
String? normalizePhoneNumber(String input, [String? defaultCountry]) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;
  if (RegExp(r'[^\d\s().+\-/]').hasMatch(trimmed)) return null;
  var digits = trimmed.replaceAll(RegExp(r'\D'), '');

  if (trimmed.startsWith('+') || digits.startsWith('00')) {
    if (digits.startsWith('00')) digits = digits.substring(2);
    if (digits.length < 8 || digits.length > 15) return null;
    final format = _formatForDialCode(digits);
    if (format != null) {
      final national = digits.substring(format.dialCode.length);
      if (!_nationalLengthOk(format, national)) return null;
    }
    return '+$digits';
  }

  final format = regionalFormatFor(defaultCountry) ?? appRegionalFormat();
  var national = digits;
  final trunk = format.phoneTrunkPrefix;
  // "07911…" in the UK; "1 555…" in the US only when the 1 is clearly extra.
  if (trunk.isNotEmpty &&
      national.startsWith(trunk) &&
      (trunk != '1' || national.length == format.phoneMaxDigits + 1)) {
    national = national.substring(trunk.length);
  }
  if (!_nationalLengthOk(format, national)) return null;
  return '+${format.dialCode}$national';
}

/// The flag of [countryCode] as an emoji (two regional-indicator letters).
String countryFlagEmoji(String countryCode) {
  final code = countryCode.toUpperCase();
  if (code.length != 2) return '';
  return String.fromCharCodes(code.runes.map((rune) => 0x1F1E6 + rune - 0x41));
}

/// Countries offered by a phone-prefix picker: the variant's own first, then
/// the others by name in the app language.
List<RegionalFormat> phoneCountriesForPicker() {
  final own = appCountryCode();
  final others = _formats.values.where((format) => format.countryCode != own).toList()
    ..sort((a, b) => (appCountryName(a.countryCode) ?? a.countryCode)
        .compareTo(appCountryName(b.countryCode) ?? b.countryCode));
  return [
    if (_formats[own] != null) _formats[own]!,
    ...others,
  ];
}

/// The country whose dial code starts an international number ("+447911…" →
/// GB), or null for a number outside the table.
RegionalFormat? regionalFormatForInternationalNumber(String international) {
  final digits = international.replaceAll(RegExp(r'\D'), '');
  return digits.isEmpty ? null : _formatForDialCode(digits);
}

/// A stored number ("+447911123456") split for an edit form: the country of
/// its dial code and the national digits grouped for reading ("7911 123456").
/// [countryCode] is null (and [national] the text as stored) when the number
/// is not in the table or not valid.
({String? countryCode, String national}) splitPhoneNumber(String stored) {
  final normalized = normalizePhoneNumber(stored);
  final format = normalized == null ? null : _formatForDialCode(normalized.substring(1));
  if (normalized == null || format == null) return (countryCode: null, national: stored.trim());
  final grouped = formatPhoneNumber(normalized);
  final dial = '+${format.dialCode} ';
  return (
    countryCode: format.countryCode,
    national: grouped.startsWith(dial) ? grouped.substring(dial.length) : grouped,
  );
}

/// [normalizePhoneNumber] grouped for reading ("+44 7911 123456"); [input]
/// unchanged when it is not a valid number.
String formatPhoneNumber(String input, [String? defaultCountry]) {
  final normalized = normalizePhoneNumber(input, defaultCountry);
  if (normalized == null) return input.trim();
  final digits = normalized.substring(1);
  final format = _formatForDialCode(digits);
  if (format == null) return normalized;
  var rest = digits.substring(format.dialCode.length);
  final groups = <String>[];
  for (final size in format.phoneGroups) {
    if (rest.isEmpty) break;
    final take = size < rest.length ? size : rest.length;
    groups.add(rest.substring(0, take));
    rest = rest.substring(take);
  }
  if (rest.isNotEmpty) groups.add(rest);
  return '+${format.dialCode} ${groups.join(' ')}';
}

bool _nationalLengthOk(RegionalFormat format, String national) =>
    national.length >= format.phoneMinDigits && national.length <= format.phoneMaxDigits;

RegionalFormat? _formatForDialCode(String internationalDigits) {
  RegionalFormat? best;
  for (final format in _formats.values) {
    if (internationalDigits.startsWith(format.dialCode) &&
        (best == null || format.dialCode.length > best.dialCode.length)) {
      best = format;
    }
  }
  return best;
}
