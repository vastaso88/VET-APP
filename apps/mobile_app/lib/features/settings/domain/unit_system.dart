/// Measurement systems the owner can choose in Impostazioni → Layout.
///
/// Everything is stored metric (meters, kg, °C, liters, cm); a system only
/// changes how a value is shown and how a typed value is read back.
///
/// Why three systems and not two: the UK mixes habits (miles, but °C and
/// litres for tanks, pounds for pets), so folding it into either "metric" or
/// "USA" would be wrong for UK owners.
///
/// | system | distance     | weight | temperature | tank volume | dimensions |
/// |--------|--------------|--------|-------------|-------------|------------|
/// | metric | m / km       | kg     | °C          | litres      | cm         |
/// | uk     | yd / mi      | lb     | °C          | litres      | in         |
/// | us     | ft / mi      | lb     | °F          | US gal      | in         |
enum UnitSystem {
  metric,
  uk,
  us;

  String get label => switch (this) {
        UnitSystem.metric => 'Metrico',
        UnitSystem.uk => 'Regno Unito',
        UnitSystem.us => 'USA',
      };

  String get description => switch (this) {
        UnitSystem.metric => 'km, kg, °C, litri',
        UnitSystem.uk => 'miglia, libbre, °C, litri',
        UnitSystem.us => 'miglia, libbre, °F, galloni USA',
      };

  bool get usesMiles => this != UnitSystem.metric;
  bool get usesPounds => this != UnitSystem.metric;
  bool get usesFahrenheit => this == UnitSystem.us;
  bool get usesUsGallons => this == UnitSystem.us;
  bool get usesInches => this != UnitSystem.metric;

  static UnitSystem? fromName(String? name) {
    for (final system in UnitSystem.values) {
      if (system.name == name) return system;
    }
    return null;
  }
}

/// The units to start from for a given locale. The single place that will
/// pick the default once the app has a language/country choice; until then
/// everyone starts metric (the app is Italian-only today).
UnitSystem defaultUnitsForLocale(String? countryCode) {
  switch (countryCode?.toUpperCase()) {
    case 'US':
    case 'LR':
    case 'MM':
      return UnitSystem.us;
    case 'GB':
    case 'UK':
      return UnitSystem.uk;
    default:
      return UnitSystem.metric;
  }
}
