import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/territory/domain/territory.dart';

import 'territory_test_helpers.dart';

void main() {
  tearDown(resetTerritoryForTest);

  test('every country has its own currency and symbol', () {
    expect(territoryFor('IT').currencySymbol, '€');
    expect(territoryFor('GB').currencySymbol, '£');
    expect(territoryFor('US').currencySymbol, r'$');
    expect(territoryFor('AU').currencySymbol, r'A$');
    expect(territoryFor('CH').currencySymbol, 'CHF');
    expect(territoryFor('de').currencyCode, 'EUR', reason: 'lower case is accepted');
    expect(territoryFor('GB').currencyCode, 'GBP');
    expect(territoryFor('AU').currencyCode, 'AUD');
  });

  test('live animals are not allowed in DACH, FR/BE, ES and UK - one table, no scattered if', () {
    const forbidden = ['DE', 'AT', 'CH', 'FR', 'BE', 'ES', 'GB'];
    for (final code in forbidden) {
      expect(territoryFor(code).liveAnimalListingsAllowed, isFalse, reason: code);
    }
    for (final code in ['IT', 'US', 'AU']) {
      expect(territoryFor(code).liveAnimalListingsAllowed, isTrue, reason: code);
    }
  });

  test('an unknown or missing country gets the source country, never another one', () {
    expect(territoryFor(null).countryCode, 'IT');
    expect(territoryFor('ZZ').countryCode, 'IT');
  });

  test('the territory follows the language variant the owner picked', () async {
    await useLanguageVariant('en-AU');
    expect(currentTerritory().countryCode, 'AU');
    await useLanguageVariant('es');
    expect(currentTerritory().countryCode, 'ES');
    expect(currentTerritory().liveAnimalListingsAllowed, isFalse);
  });

  test('radius options end at the maximum: 50 km, or 30 mi, never "everywhere"', () {
    final km = marketplaceRadiusOptionsKm(miles: false);
    expect(km, [2, 5, 10, 25, 50]);
    expect(km.last, marketplaceMaxRadiusKm);

    final mi = marketplaceRadiusOptionsKm(miles: true);
    expect(mi.length, 5);
    expect(mi.last, closeTo(48.28, 0.01));
    expect(mi.last, lessThanOrEqualTo(marketplaceMaxRadiusKm));
    expect(kmToMiles(mi.last), closeTo(marketplaceMaxRadiusMiles, 0.001));
  });

  test('the default radius is one of the options, in both units', () {
    expect(marketplaceRadiusOptionsKm(miles: false), contains(defaultMarketplaceRadiusKm(miles: false)));
    expect(marketplaceRadiusOptionsKm(miles: true), contains(defaultMarketplaceRadiusKm(miles: true)));
  });

  test('a radius is clamped into (0, 50] km', () {
    expect(clampMarketplaceRadiusKm(500), marketplaceMaxRadiusKm);
    expect(clampMarketplaceRadiusKm(-3), 0.1);
    expect(clampMarketplaceRadiusKm(12), 12);
  });
}
