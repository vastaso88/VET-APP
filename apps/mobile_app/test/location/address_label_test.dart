import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/location/data/address_geocoder.dart';

void main() {
  test('builds "via civico, città" from the structured Nominatim address', () {
    final label = compactAddressLabel(
      {
        'house_number': '1',
        'road': 'Piazza del Duomo',
        'suburb': 'Duomo',
        'city': 'Milano',
        'state': 'Lombardia',
      },
      '1, Piazza del Duomo, Duomo, Municipio 1, Milano, Lombardia, 20122, Italia',
    );

    expect(label, 'Piazza del Duomo 1, Milano');
  });

  test('falls back to the display name when the street or city is missing', () {
    const display = 'Some place, Somewhere, Italia';
    expect(compactAddressLabel({'city': 'Milano'}, display), display);
    expect(compactAddressLabel({'road': 'Via Roma'}, display), display);
    expect(compactAddressLabel(null, display), display);
  });

  test('uses town or village when there is no city', () {
    final label = compactAddressLabel(
      {'road': 'Via Roma', 'house_number': '10', 'village': 'Borgo Antico'},
      'x',
    );
    expect(label, 'Via Roma 10, Borgo Antico');
  });

  test('writes each country in its own order, postcode included', () {
    expect(
      compactAddressLabel({
        'road': 'Via Esempio',
        'house_number': '12',
        'postcode': '20100',
        'city': 'Milano',
        'country_code': 'it',
      }, 'x'),
      'Via Esempio 12, 20100 Milano',
    );
    expect(
      compactAddressLabel({
        'road': 'Example St',
        'house_number': '12',
        'postcode': '62704',
        'city': 'Springfield',
        'ISO3166-2-lvl4': 'US-IL',
        'country_code': 'us',
      }, 'x'),
      '12 Example St, Springfield, IL 62704',
    );
    expect(
      compactAddressLabel({
        'road': 'Musterstraße',
        'house_number': '12',
        'postcode': '10115',
        'city': 'Berlin',
        'country_code': 'de',
      }, 'x'),
      'Musterstraße 12, 10115 Berlin',
    );
  });

  group('isLegacyLongAddressLabel', () {
    test('flags a raw Nominatim display_name (3+ commas)', () {
      expect(isLegacyLongAddressLabel('1, Piazza del Duomo, Duomo, Municipio 1, Milano'), isTrue);
    });

    test('flags a label over 60 characters even with few commas', () {
      expect(isLegacyLongAddressLabel('${'a' * 61}, Milano'), isTrue);
    });

    test('keeps an already compact label', () {
      expect(isLegacyLongAddressLabel('Piazza del Duomo 1, Milano'), isFalse);
    });
  });
}
