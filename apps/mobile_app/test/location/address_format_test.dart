import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/location/domain/address_format.dart';
import 'package:vet_app_mobile/features/location/domain/supported_countries.dart';

// The same cases as tests/unit/test_radar_countries.py on the backend: the
// two implementations must write every country's address alike.
void main() {
  group('formatAddress', () {
    final cases = <(String, AddressParts, String)>[
      (
        'IT',
        const AddressParts(
          street: 'Via Roma',
          houseNumber: '12',
          postcode: '20100',
          city: 'Milano',
        ),
        'Via Roma 12, 20100 Milano',
      ),
      (
        'US',
        const AddressParts(
          street: 'Main St',
          houseNumber: '12',
          postcode: '62704',
          city: 'Springfield',
          state: 'IL',
        ),
        '12 Main St, Springfield, IL 62704',
      ),
      (
        'US',
        const AddressParts(
          street: 'Main St',
          houseNumber: '12',
          postcode: '62704',
          city: 'Springfield',
          state: 'US-IL',
        ),
        '12 Main St, Springfield, IL 62704',
      ),
      (
        'GB',
        const AddressParts(
          street: 'Downing Street',
          houseNumber: '10',
          postcode: 'SW1A 2AA',
          city: 'London',
        ),
        '10 Downing Street, London SW1A 2AA',
      ),
      (
        'DE',
        const AddressParts(
          street: 'Musterstraße',
          houseNumber: '12',
          postcode: '10115',
          city: 'Berlin',
        ),
        'Musterstraße 12, 10115 Berlin',
      ),
      (
        'FR',
        const AddressParts(
          street: 'rue de la Paix',
          houseNumber: '12',
          postcode: '75002',
          city: 'Paris',
        ),
        '12 rue de la Paix, 75002 Paris',
      ),
      (
        'ES',
        const AddressParts(
          street: 'Calle Mayor',
          houseNumber: '12',
          postcode: '28013',
          city: 'Madrid',
        ),
        'Calle Mayor 12, 28013 Madrid',
      ),
      (
        'AU',
        const AddressParts(
          street: 'George St',
          houseNumber: '12',
          postcode: '2000',
          city: 'Sydney',
          state: 'nsw',
        ),
        '12 George St, Sydney NSW 2000',
      ),
    ];
    for (final (country, parts, expected) in cases) {
      test('$country: $expected', () {
        expect(formatAddress(parts, country), expected);
      });
    }

    test('leaves out missing parts without stray separators', () {
      expect(
        formatAddress(
          const AddressParts(street: 'Via Roma', city: 'Milano'),
          'IT',
        ),
        'Via Roma, Milano',
      );
      expect(
        formatAddress(
          const AddressParts(
            postcode: '62704',
            city: 'Springfield',
            state: 'IL',
          ),
          'US',
        ),
        'Springfield, IL 62704',
      );
      expect(formatAddress(const AddressParts(city: 'Berlin'), 'DE'), 'Berlin');
      expect(formatAddress(const AddressParts(), 'FR'), '');
      expect(
        formatAddress(
          const AddressParts(street: '  Calle   Mayor ', houseNumber: ' 12 '),
          'ES',
        ),
        'Calle Mayor 12',
      );
    });

    test('an unknown country gets the European order', () {
      const parts = AddressParts(
        street: 'Rua Exemplo',
        houseNumber: '5',
        postcode: '1000',
        city: 'Lisboa',
      );
      expect(formatAddress(parts, null), 'Rua Exemplo 5, 1000 Lisboa');
      expect(formatAddress(parts, 'pt'), 'Rua Exemplo 5, 1000 Lisboa');
    });
  });

  group('AddressParts.fromNominatim', () {
    test('reads the US state from the ISO code, not the long name', () {
      final parts = AddressParts.fromNominatim({
        'house_number': '12',
        'road': 'Main St',
        'city': 'Springfield',
        'state': 'Illinois',
        'ISO3166-2-lvl4': 'US-IL',
        'postcode': '62704',
      });
      expect(formatAddress(parts, 'us'), '12 Main St, Springfield, IL 62704');
    });

    test('falls back from city to town, village, municipality', () {
      expect(
        AddressParts.fromNominatim({'road': 'Via X', 'village': 'Borgo'}).city,
        'Borgo',
      );
      expect(
        AddressParts.fromNominatim({
          'road': 'Via X',
          'municipality': 'Comune',
        }).city,
        'Comune',
      );
    });
  });

  group('supportedCountryForName', () {
    test('recognizes the seven countries by name in the app languages', () {
      expect(supportedCountryForName('Italia')?.code, 'IT');
      expect(supportedCountryForName('United Kingdom')?.code, 'GB');
      expect(supportedCountryForName('  Regno Unito ')?.code, 'GB');
      expect(supportedCountryForName('U.S.A.')?.code, 'US');
      expect(supportedCountryForName('Stati Uniti')?.code, 'US');
      expect(supportedCountryForName('Australia')?.code, 'AU');
      expect(supportedCountryForName('Deutschland')?.code, 'DE');
      expect(supportedCountryForName('France')?.code, 'FR');
      expect(supportedCountryForName('España')?.code, 'ES');
      expect(supportedCountryForName('de')?.nominatimCode, 'de');
    });

    test('returns null for an unsupported or empty country', () {
      expect(supportedCountryForName('Giappone'), isNull);
      expect(supportedCountryForName(''), isNull);
    });

    test('has one flag per country, all different', () {
      expect(supportedCountries.map((c) => c.code), [
        'IT',
        'GB',
        'US',
        'AU',
        'DE',
        'FR',
        'ES',
      ]);
      expect(
        supportedCountries.map((c) => c.flag).toSet().length,
        supportedCountries.length,
      );
    });
  });
}
