import '../../language/data/language_store.dart';

/// Everything that depends on the country the owner lives in, in ONE place:
/// news edition, currency, Mercatino rules. Features read a [Territory]
/// instead of branching on country codes themselves, so adding a country is
/// a new row in [_territories] (and, for the backend, the same row in
/// packages/core/domain/territory/rules.py - keep the two in step, the
/// tests on both sides pin the same values).
///
/// The country is the one of the app's language variant (🇬🇧 🇺🇸 🇦🇺 🇩🇪 🇫🇷
/// 🇪🇸 🇮🇹): it is what the owner chose at first launch and can change in
/// Impostazioni → Lingua. A "Paese" setting separate from the language (an
/// English speaker living in Germany) is an open product question.
class Territory {
  const Territory({
    required this.countryCode,
    required this.currencyCode,
    required this.currencySymbol,
    required this.liveAnimalListingsAllowed,
  });

  /// ISO 3166-1 alpha-2, upper case.
  final String countryCode;

  /// ISO 4217, used to name the currency in a price field label.
  final String currencyCode;

  /// How a price is written: €, £, $, A$, CHF.
  final String currencySymbol;

  /// False where the Mercatino must not carry ads for living animals
  /// (docs/i18n/NOTIZIE_EVENTI_MERCATINO.md, "Animali vivi"). The Mercatino
  /// only sells things for animals; where this is false the author also has
  /// to confirm that the ad offers no animal.
  final bool liveAnimalListingsAllowed;
}

/// Largest Mercatino search radius, whatever the unit shown (30 mi is 48.3 km,
/// inside it). Mirrored by MARKETPLACE_MAX_RADIUS_KM in the backend.
const marketplaceMaxRadiusKm = 50.0;

const _miPerKm = 0.621371192;
const _kmPerMi = 1.609344;

/// Largest radius in miles for owners whose units are miles.
const marketplaceMaxRadiusMiles = 30.0;

const _territories = <String, Territory>{
  'IT': Territory(
    countryCode: 'IT',
    currencyCode: 'EUR',
    currencySymbol: '€',
    liveAnimalListingsAllowed: true,
  ),
  'GB': Territory(
    countryCode: 'GB',
    currencyCode: 'GBP',
    currencySymbol: '£',
    liveAnimalListingsAllowed: false,
  ),
  'US': Territory(
    countryCode: 'US',
    currencyCode: 'USD',
    currencySymbol: r'$',
    liveAnimalListingsAllowed: true,
  ),
  'AU': Territory(
    countryCode: 'AU',
    currencyCode: 'AUD',
    currencySymbol: r'A$',
    liveAnimalListingsAllowed: true,
  ),
  'DE': Territory(
    countryCode: 'DE',
    currencyCode: 'EUR',
    currencySymbol: '€',
    liveAnimalListingsAllowed: false,
  ),
  'AT': Territory(
    countryCode: 'AT',
    currencyCode: 'EUR',
    currencySymbol: '€',
    liveAnimalListingsAllowed: false,
  ),
  'CH': Territory(
    countryCode: 'CH',
    currencyCode: 'CHF',
    currencySymbol: 'CHF',
    liveAnimalListingsAllowed: false,
  ),
  'FR': Territory(
    countryCode: 'FR',
    currencyCode: 'EUR',
    currencySymbol: '€',
    liveAnimalListingsAllowed: false,
  ),
  'BE': Territory(
    countryCode: 'BE',
    currencyCode: 'EUR',
    currencySymbol: '€',
    liveAnimalListingsAllowed: false,
  ),
  'ES': Territory(
    countryCode: 'ES',
    currencyCode: 'EUR',
    currencySymbol: '€',
    liveAnimalListingsAllowed: false,
  ),
};

/// The country of the source language, used when a country is unknown.
const sourceTerritoryCode = 'IT';

/// Country codes the app has rules for.
Iterable<String> get knownTerritoryCodes => _territories.keys;

/// The rules for [countryCode]; an unknown or missing country gets the
/// source country's rules (Italy), never a guess from another one.
Territory territoryFor(String? countryCode) =>
    _territories[countryCode?.toUpperCase()] ?? _territories[sourceTerritoryCode]!;

/// The territory of the owner right now: the country of the chosen language
/// variant.
Territory currentTerritory() => territoryFor(LanguageStore.instance.variant.countryCode);

/// Search-radius choices in the unit the owner reads ("1 / 3 / 5 / 15 / 30
/// mi" or "2 / 5 / 10 / 25 / 50 km"), as kilometres. The last one is always
/// the maximum; there is no "everywhere". The default is one of them.
List<double> marketplaceRadiusOptionsKm({required bool miles}) => miles
    ? const [1, 3, 5, 15, 30].map((mi) => mi * _kmPerMi).toList(growable: false)
    : const [2.0, 5.0, 10.0, 25.0, marketplaceMaxRadiusKm];

/// Radius preselected for an owner with a position: 25 km, or 15 mi.
double defaultMarketplaceRadiusKm({required bool miles}) => miles ? 15 * _kmPerMi : 25;

/// Kilometres -> miles, for showing the radius.
double kmToMiles(double km) => km * _miPerKm;

/// [radiusKm] never above the maximum, never below a metre-scale minimum.
double clampMarketplaceRadiusKm(double radiusKm) =>
    radiusKm.clamp(0.1, marketplaceMaxRadiusKm).toDouble();
