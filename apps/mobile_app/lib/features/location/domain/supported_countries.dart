/// The countries the radar and the address search are built for (the same
/// seven as `packages/core/domain/geo/countries.py`). Used to tell
/// Nominatim which country a typed address is in, so a street name that
/// exists in several countries resolves in the right one.
library;

class SupportedCountry {
  const SupportedCountry(this.code, this.flag, this.names);

  /// ISO 3166-1 alpha-2.
  final String code;
  final String flag;

  /// Lower-case names a person may type, in the app's languages and the
  /// country's own.
  final List<String> names;

  /// Value of Nominatim's `countrycodes` parameter.
  String get nominatimCode => code.toLowerCase();
}

const supportedCountries = <SupportedCountry>[
  SupportedCountry('IT', '🇮🇹', ['italia', 'italy', 'italien', 'italie']),
  SupportedCountry('GB', '🇬🇧', [
    'regno unito',
    'united kingdom',
    'uk',
    'gb',
    'great britain',
    'gran bretagna',
    'gran bretana',
    'england',
    'scotland',
    'wales',
    'northern ireland',
    'reino unido',
    'vereinigtes konigreich',
    'royaume-uni',
  ]),
  SupportedCountry('US', '🇺🇸', [
    'stati uniti',
    'stati uniti d\'america',
    'usa',
    'us',
    'united states',
    'united states of america',
    'estados unidos',
    'vereinigte staaten',
    'etats-unis',
  ]),
  SupportedCountry('AU', '🇦🇺', ['australia', 'australien', 'australie']),
  SupportedCountry('DE', '🇩🇪', [
    'germania',
    'germany',
    'deutschland',
    'alemania',
    'allemagne',
  ]),
  SupportedCountry('FR', '🇫🇷', ['francia', 'france', 'frankreich']),
  SupportedCountry('ES', '🇪🇸', [
    'spagna',
    'spain',
    'espana',
    'spanien',
    'espagne',
  ]),
];

// Accented letters of the countries' names, folded to plain ones.
// Written as escapes: a-acute a-grave a-umlaut a-circumflex, e..., i..., o..., u..., n-tilde, c-cedilla.
const _accentedLetters = '\u00e1\u00e0\u00e4\u00e2\u00e9\u00e8\u00ea\u00eb\u00ed\u00ec\u00ef\u00ee\u00f3\u00f2\u00f6\u00f4\u00fa\u00f9\u00fc\u00fb\u00f1\u00e7';
const _plainLetters = 'aaaaeeeeiiiioooouuuunc';

String _fold(String text) {
  final folded = StringBuffer();
  for (final char in text.split('')) {
    final at = _accentedLetters.indexOf(char);
    folded.write(at < 0 ? char : _plainLetters[at]);
  }
  return folded.toString();
}

/// The supported country a typed name (or ISO code) stands for, or null.
/// Case, accents and dots are ignored ("España", "U.S.A.").
SupportedCountry? supportedCountryForName(String name) {
  final wanted = _fold(name.trim().toLowerCase().replaceAll('.', ''));
  if (wanted.isEmpty) return null;
  for (final country in supportedCountries) {
    if (country.code.toLowerCase() == wanted ||
        country.names.contains(wanted)) {
      return country;
    }
  }
  return null;
}
