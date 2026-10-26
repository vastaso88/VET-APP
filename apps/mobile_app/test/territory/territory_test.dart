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

  test('quick radius options are 10 / 25 / 50 / 100 km and the default is 50', () {
    expect(marketplaceRadiusOptionsKm, [10, 25, 50, 100]);
    expect(defaultMarketplaceRadiusKm(), 50);
    expect(marketplaceRadiusOptionsKm, contains(defaultMarketplaceRadiusKm()));
    expect(marketplaceRadiusOptionsKm.last, lessThanOrEqualTo(marketplaceMaxRadiusKm));
  });

  test('a radius is clamped into [1, 300] km', () {
    expect(clampMarketplaceRadiusKm(500), 300);
    expect(clampMarketplaceRadiusKm(-3), 1);
    expect(clampMarketplaceRadiusKm(0.2), 1);
    expect(clampMarketplaceRadiusKm(12), 12);
  });

  test('"Altro" takes whole numbers 1-300 km, or miles that are stored as km', () {
    expect(marketplaceRadiusFromInput('1', miles: false), 1);
    expect(marketplaceRadiusFromInput(' 35 ', miles: false), 35);
    expect(marketplaceRadiusFromInput('300', miles: false), 300);
    for (final bad in ['0', '301', '-5', '2.5', '', 'abc', '1e2']) {
      expect(marketplaceRadiusFromInput(bad, miles: false), isNull, reason: bad);
    }

    expect(marketplaceRadiusFromInput('10', miles: true), 16);
    expect(marketplaceRadiusFromInput('186', miles: true), 299);
    expect(marketplaceRadiusFromInput('187', miles: true), isNull);
    expect(marketplaceRadiusFromInput('0', miles: true), isNull);
    expect(marketplaceMaxRadiusInput(miles: true), 186);
    expect(marketplaceMaxRadiusInput(miles: false), 300);
  });
}
