import '../../../l10n/regional_defaults.dart' show appCurrencySymbol;
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
  });

  /// ISO 3166-1 alpha-2, upper case.
  final String countryCode;

  /// ISO 4217, used to name the currency in a price field label.
  final String currencyCode;

  /// How a price is written: €, £, $, A$, CHF. Taken from the one currency
  /// table of the app (l10n/regional_defaults.dart), never repeated here.
  String get currencySymbol => appCurrencySymbol(currencyCode);
}

/// Mercatino search radius bounds in whole kilometres, whatever the unit shown
/// (owner decision 2026-10-26). Mirrored by MARKETPLACE_MIN_RADIUS_KM and
/// MARKETPLACE_MAX_RADIUS_KM in the backend; the app always stores and sends km.
const marketplaceMinRadiusKm = 1.0;
const marketplaceMaxRadiusKm = 300.0;

/// Radius preselected, and the one a fresh install starts from.
const defaultMarketplaceRadiusKmValue = 50.0;

const _miPerKm = 0.621371192;
const _kmPerMi = 1.609344;

const _territories = <String, Territory>{
  'IT': Territory(
    countryCode: 'IT',
    currencyCode: 'EUR',
  ),
  'GB': Territory(
    countryCode: 'GB',
    currencyCode: 'GBP',
  ),
  'US': Territory(
    countryCode: 'US',
    currencyCode: 'USD',
  ),
  'AU': Territory(
    countryCode: 'AU',
    currencyCode: 'AUD',
  ),
  'DE': Territory(
    countryCode: 'DE',
    currencyCode: 'EUR',
  ),
  'AT': Territory(
    countryCode: 'AT',
    currencyCode: 'EUR',
  ),
  'CH': Territory(
    countryCode: 'CH',
    currencyCode: 'CHF',
  ),
  'FR': Territory(
    countryCode: 'FR',
    currencyCode: 'EUR',
  ),
  'BE': Territory(
    countryCode: 'BE',
    currencyCode: 'EUR',
  ),
  'ES': Territory(
    countryCode: 'ES',
    currencyCode: 'EUR',
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

/// The quick search-radius choices, in kilometres: the filter also has an
/// "Altro" chip for any whole value from [marketplaceMinRadiusKm] to
/// [marketplaceMaxRadiusKm]. There is no "everywhere". Owners who read miles
/// see the same values converted, but the radius is always kept and sent in km.
const marketplaceRadiusOptionsKm = <double>[10, 25, 50, 100];

/// Radius preselected for an owner with a position.
double defaultMarketplaceRadiusKm() => defaultMarketplaceRadiusKmValue;

/// A radius typed by the owner, in kilometres or in miles, as whole
/// kilometres; null when it is not a whole number or falls outside
/// [marketplaceMinRadiusKm]..[marketplaceMaxRadiusKm].
double? marketplaceRadiusFromInput(String text, {required bool miles}) {
  final value = int.tryParse(text.trim());
  if (value == null) return null;
  final km = miles ? (value * _kmPerMi).round() : value;
  if (km < marketplaceMinRadiusKm || km > marketplaceMaxRadiusKm) return null;
  return km.toDouble();
}

/// The largest whole number the "Altro" field accepts, in the unit shown.
int marketplaceMaxRadiusInput({required bool miles}) =>
    miles ? (marketplaceMaxRadiusKm * _miPerKm).floor() : marketplaceMaxRadiusKm.toInt();

/// Kilometres -> miles, for showing the radius.
double kmToMiles(double km) => km * _miPerKm;

/// [radiusKm] inside the accepted range.
double clampMarketplaceRadiusKm(double radiusKm) =>
    radiusKm.clamp(marketplaceMinRadiusKm, marketplaceMaxRadiusKm).toDouble();
