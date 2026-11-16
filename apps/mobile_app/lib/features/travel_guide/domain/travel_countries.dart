/// The countries a person can pick in "Around the world" (docs/product/18).
///
/// Names are data, not interface text: they are written in Italian here (the
/// app's source language) and matched without accents or capitals, with a few
/// aliases people really type (USA, UK, Emirati). Translating the names to the
/// other languages is a later step with the translation review.
library;

class TravelCountry {
  const TravelCountry(this.code, this.name, [this.aliases = const []]);

  /// ISO 3166-1 alpha-2.
  final String code;
  final String name;
  final List<String> aliases;

  /// The flag emoji, built from the two letters of the code.
  String get flag => String.fromCharCodes([
        for (final unit in code.codeUnits) 0x1F1E6 + (unit - 0x41),
      ]);

  bool matches(String query) {
    final needle = normalizeCountryText(query);
    if (needle.isEmpty) return true;
    if (normalizeCountryText(name).contains(needle)) return true;
    return aliases.any((alias) => normalizeCountryText(alias).contains(needle));
  }
}

/// The member states of the European Union: the origin of a journey is
/// "UE" when it starts from one of them (docs/product/18 §2.1).
const euMemberStates = <String>{
  'AT', 'BE', 'BG', 'HR', 'CY', 'CZ', 'DK', 'EE', 'FI', 'FR', 'DE', 'GR', 'HU', 'IE', 'IT', //
  'LV', 'LT', 'LU', 'MT', 'NL', 'PL', 'PT', 'RO', 'SK', 'SI', 'ES', 'SE',
};

bool isEuMemberState(String code) => euMemberStates.contains(code.toUpperCase());

/// Lower case, without accents, with single spaces: how both the query and the
/// names are compared.
String normalizeCountryText(String value) {
  // The accented letters people type, as escapes (a, e, i, o, u, c and n with accents).
  const from = '\u00e0\u00e1\u00e2\u00e3\u00e4\u00e5\u00e8\u00e9\u00ea\u00eb\u00ec\u00ed\u00ee\u00ef'
      '\u00f2\u00f3\u00f4\u00f5\u00f6\u00f9\u00fa\u00fb\u00fc\u00e7\u00f1';
  const to = 'aaaaaaeeeeiiiiooooouuuucn';
  final buffer = StringBuffer();
  for (final rune in value.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    final index = from.indexOf(char);
    buffer.write(index >= 0 ? to[index] : char);
  }
  return buffer.toString().replaceAll(RegExp(r'[^a-z0-9 ]'), ' ').replaceAll(RegExp(r' +'), ' ').trim();
}

TravelCountry? travelCountryByCode(String code) {
  final upper = code.toUpperCase();
  for (final country in travelCountries) {
    if (country.code == upper) return country;
  }
  return null;
}

/// Countries whose name matches [query], best first (names that start with the
/// query before names that only contain it).
List<TravelCountry> searchTravelCountries(String query) {
  final needle = normalizeCountryText(query);
  final found = travelCountries.where((country) => country.matches(query)).toList();
  if (needle.isEmpty) return found;
  int rank(TravelCountry c) =>
      normalizeCountryText(c.name).startsWith(needle) || c.aliases.any((a) => normalizeCountryText(a) == needle)
          ? 0
          : 1;
  found.sort((a, b) {
    final byRank = rank(a).compareTo(rank(b));
    return byRank != 0 ? byRank : a.name.compareTo(b.name);
  });
  return found;
}

const travelCountries = <TravelCountry>[
  TravelCountry('AF', 'Afghanistan'),
  TravelCountry('AL', 'Albania'),
  TravelCountry('DZ', 'Algeria'),
  TravelCountry('AD', 'Andorra'),
  TravelCountry('AO', 'Angola'),
  TravelCountry('AG', 'Antigua e Barbuda'),
  TravelCountry('SA', 'Arabia Saudita'),
  TravelCountry('AR', 'Argentina'),
  TravelCountry('AM', 'Armenia'),
  TravelCountry('AU', 'Australia'),
  TravelCountry('AT', 'Austria'),
  TravelCountry('AZ', 'Azerbaigian'),
  TravelCountry('BS', 'Bahamas'),
  TravelCountry('BH', 'Bahrein'),
  TravelCountry('BD', 'Bangladesh'),
  TravelCountry('BB', 'Barbados'),
  TravelCountry('BE', 'Belgio'),
  TravelCountry('BZ', 'Belize'),
  TravelCountry('BJ', 'Benin'),
  TravelCountry('BT', 'Bhutan'),
  TravelCountry('BY', 'Bielorussia'),
  TravelCountry('BO', 'Bolivia'),
  TravelCountry('BA', 'Bosnia ed Erzegovina'),
  TravelCountry('BW', 'Botswana'),
  TravelCountry('BR', 'Brasile'),
  TravelCountry('BN', 'Brunei'),
  TravelCountry('BG', 'Bulgaria'),
  TravelCountry('BF', 'Burkina Faso'),
  TravelCountry('BI', 'Burundi'),
  TravelCountry('KH', 'Cambogia'),
  TravelCountry('CM', 'Camerun'),
  TravelCountry('CA', 'Canada'),
  TravelCountry('CV', 'Capo Verde'),
  TravelCountry('TD', 'Ciad'),
  TravelCountry('CL', 'Cile'),
  TravelCountry('CN', 'Cina'),
  TravelCountry('CY', 'Cipro'),
  TravelCountry('CO', 'Colombia'),
  TravelCountry('KM', 'Comore'),
  TravelCountry('CG', 'Congo'),
  TravelCountry('CD', 'Repubblica Democratica del Congo', ['Congo RDC']),
  TravelCountry('KP', 'Corea del Nord'),
  TravelCountry('KR', 'Corea del Sud'),
  TravelCountry('CI', 'Costa d\'Avorio'),
  TravelCountry('CR', 'Costa Rica'),
  TravelCountry('HR', 'Croazia'),
  TravelCountry('CU', 'Cuba'),
  TravelCountry('DK', 'Danimarca'),
  TravelCountry('DM', 'Dominica'),
  TravelCountry('EC', 'Ecuador'),
  TravelCountry('EG', 'Egitto'),
  TravelCountry('SV', 'El Salvador'),
  TravelCountry('AE', 'Emirati Arabi Uniti', ['Emirati', 'Dubai', 'Abu Dhabi', 'UAE']),
  TravelCountry('ER', 'Eritrea'),
  TravelCountry('EE', 'Estonia'),
  TravelCountry('SZ', 'Eswatini'),
  TravelCountry('ET', 'Etiopia'),
  TravelCountry('FJ', 'Figi'),
  TravelCountry('PH', 'Filippine'),
  TravelCountry('FI', 'Finlandia'),
  TravelCountry('FR', 'Francia'),
  TravelCountry('GA', 'Gabon'),
  TravelCountry('GM', 'Gambia'),
  TravelCountry('GE', 'Georgia'),
  TravelCountry('DE', 'Germania'),
  TravelCountry('GH', 'Ghana'),
  TravelCountry('JM', 'Giamaica'),
  TravelCountry('JP', 'Giappone'),
  TravelCountry('DJ', 'Gibuti'),
  TravelCountry('JO', 'Giordania'),
  TravelCountry('GR', 'Grecia'),
  TravelCountry('GD', 'Grenada'),
  TravelCountry('GT', 'Guatemala'),
  TravelCountry('GN', 'Guinea'),
  TravelCountry('GW', 'Guinea-Bissau'),
  TravelCountry('GQ', 'Guinea Equatoriale'),
  TravelCountry('GY', 'Guyana'),
  TravelCountry('HT', 'Haiti'),
  TravelCountry('HN', 'Honduras'),
  TravelCountry('IN', 'India'),
  TravelCountry('ID', 'Indonesia', ['Bali']),
  TravelCountry('IR', 'Iran'),
  TravelCountry('IQ', 'Iraq'),
  TravelCountry('IE', 'Irlanda'),
  TravelCountry('IS', 'Islanda'),
  TravelCountry('IL', 'Israele'),
  TravelCountry('IT', 'Italia'),
  TravelCountry('KZ', 'Kazakistan'),
  TravelCountry('KE', 'Kenya'),
  TravelCountry('KG', 'Kirghizistan'),
  TravelCountry('KI', 'Kiribati'),
  TravelCountry('XK', 'Kosovo'),
  TravelCountry('KW', 'Kuwait'),
  TravelCountry('LA', 'Laos'),
  TravelCountry('LS', 'Lesotho'),
  TravelCountry('LV', 'Lettonia'),
  TravelCountry('LB', 'Libano'),
  TravelCountry('LR', 'Liberia'),
  TravelCountry('LY', 'Libia'),
  TravelCountry('LI', 'Liechtenstein'),
  TravelCountry('LT', 'Lituania'),
  TravelCountry('LU', 'Lussemburgo'),
  TravelCountry('MK', 'Macedonia del Nord'),
  TravelCountry('MG', 'Madagascar'),
  TravelCountry('MW', 'Malawi'),
  TravelCountry('MY', 'Malesia'),
  TravelCountry('MV', 'Maldive'),
  TravelCountry('ML', 'Mali'),
  TravelCountry('MT', 'Malta'),
  TravelCountry('MA', 'Marocco'),
  TravelCountry('MH', 'Isole Marshall'),
  TravelCountry('MR', 'Mauritania'),
  TravelCountry('MU', 'Mauritius'),
  TravelCountry('MX', 'Messico'),
  TravelCountry('FM', 'Micronesia'),
  TravelCountry('MD', 'Moldavia'),
  TravelCountry('MC', 'Monaco', ['Principato di Monaco']),
  TravelCountry('MN', 'Mongolia'),
  TravelCountry('ME', 'Montenegro'),
  TravelCountry('MZ', 'Mozambico'),
  TravelCountry('MM', 'Myanmar', ['Birmania']),
  TravelCountry('NA', 'Namibia'),
  TravelCountry('NR', 'Nauru'),
  TravelCountry('NP', 'Nepal'),
  TravelCountry('NI', 'Nicaragua'),
  TravelCountry('NE', 'Niger'),
  TravelCountry('NG', 'Nigeria'),
  TravelCountry('NO', 'Norvegia'),
  TravelCountry('NZ', 'Nuova Zelanda'),
  TravelCountry('OM', 'Oman'),
  TravelCountry('NL', 'Paesi Bassi', ['Olanda']),
  TravelCountry('PK', 'Pakistan'),
  TravelCountry('PW', 'Palau'),
  TravelCountry('PA', 'Panama'),
  TravelCountry('PG', 'Papua Nuova Guinea'),
  TravelCountry('PY', 'Paraguay'),
  TravelCountry('PE', 'Peru'),
  TravelCountry('PL', 'Polonia'),
  TravelCountry('PT', 'Portogallo'),
  TravelCountry('QA', 'Qatar'),
  TravelCountry('GB', 'Regno Unito', ['UK', 'Inghilterra', 'Scozia', 'Galles', 'Irlanda del Nord', 'Gran Bretagna', 'Great Britain']),
  TravelCountry('CZ', 'Repubblica Ceca', ['Cechia']),
  TravelCountry('CF', 'Repubblica Centrafricana'),
  TravelCountry('DO', 'Repubblica Dominicana'),
  TravelCountry('RO', 'Romania'),
  TravelCountry('RW', 'Ruanda'),
  TravelCountry('RU', 'Russia'),
  TravelCountry('KN', 'Saint Kitts e Nevis'),
  TravelCountry('LC', 'Saint Lucia'),
  TravelCountry('VC', 'Saint Vincent e Grenadine'),
  TravelCountry('WS', 'Samoa'),
  TravelCountry('SM', 'San Marino'),
  TravelCountry('ST', 'Sao Tome e Principe'),
  TravelCountry('SN', 'Senegal'),
  TravelCountry('RS', 'Serbia'),
  TravelCountry('SC', 'Seychelles'),
  TravelCountry('SL', 'Sierra Leone'),
  TravelCountry('SG', 'Singapore'),
  TravelCountry('SY', 'Siria'),
  TravelCountry('SK', 'Slovacchia'),
  TravelCountry('SI', 'Slovenia'),
  TravelCountry('SO', 'Somalia'),
  TravelCountry('ES', 'Spagna'),
  TravelCountry('LK', 'Sri Lanka'),
  TravelCountry('US', 'Stati Uniti', ['USA', 'Stati Uniti d\'America', 'America', 'Hawaii']),
  TravelCountry('ZA', 'Sudafrica'),
  TravelCountry('SD', 'Sudan'),
  TravelCountry('SS', 'Sudan del Sud'),
  TravelCountry('SR', 'Suriname'),
  TravelCountry('SE', 'Svezia'),
  TravelCountry('CH', 'Svizzera'),
  TravelCountry('TJ', 'Tagikistan'),
  TravelCountry('TH', 'Thailandia', ['Tailandia']),
  TravelCountry('TW', 'Taiwan'),
  TravelCountry('TZ', 'Tanzania'),
  TravelCountry('TL', 'Timor Est'),
  TravelCountry('TG', 'Togo'),
  TravelCountry('TO', 'Tonga'),
  TravelCountry('TT', 'Trinidad e Tobago'),
  TravelCountry('TN', 'Tunisia'),
  TravelCountry('TR', 'Turchia', ['Turkiye']),
  TravelCountry('TM', 'Turkmenistan'),
  TravelCountry('TV', 'Tuvalu'),
  TravelCountry('UA', 'Ucraina'),
  TravelCountry('UG', 'Uganda'),
  TravelCountry('HU', 'Ungheria'),
  TravelCountry('UY', 'Uruguay'),
  TravelCountry('UZ', 'Uzbekistan'),
  TravelCountry('VU', 'Vanuatu'),
  TravelCountry('VA', 'Citta del Vaticano', ['Vaticano', 'Santa Sede']),
  TravelCountry('VE', 'Venezuela'),
  TravelCountry('VN', 'Vietnam'),
  TravelCountry('YE', 'Yemen'),
  TravelCountry('ZM', 'Zambia'),
  TravelCountry('ZW', 'Zimbabwe'),
];
