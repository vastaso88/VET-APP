import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vet_app_mobile/features/location/data/address_geocoder.dart';

void main() {
  http.Client clientAnswering(
    Map<String, dynamic> match,
    void Function(Uri uri) onRequest,
  ) {
    return MockClient((request) async {
      onRequest(request.url);
      return http.Response(
        jsonEncode([match]),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
  }

  test(
    'limits the search to the typed supported country and writes the query in its order',
    () async {
      late Uri seen;
      final geocoder = NominatimAddressGeocoder(
        client: clientAnswering({
          'lat': '41.88',
          'lon': '-87.63',
          'display_name': 'unused',
          'address': {
            'house_number': '12',
            'road': 'Example St',
            'city': 'Springfield',
            'state': 'Illinois',
            'ISO3166-2-lvl4': 'US-IL',
            'postcode': '62704',
            'country_code': 'us',
          },
        }, (uri) => seen = uri),
      );

      final result = await geocoder.geocode(
        street: '12 Example St',
        postalCode: '62704',
        city: 'Springfield',
        country: 'United States',
      );

      expect(seen.queryParameters['countrycodes'], 'us');
      expect(
        seen.queryParameters['q'],
        '12 Example St, Springfield, 62704, United States',
      );
      expect(result?.displayLabel, '12 Example St, Springfield, IL 62704');
      expect(result?.coordinates.latitude, 41.88);
    },
  );

  test('sends no countrycodes for a country the radar does not know', () async {
    late Uri seen;
    final geocoder = NominatimAddressGeocoder(
      client: clientAnswering({
        'lat': '35.68',
        'lon': '139.65',
        'display_name': 'Somewhere, Japan',
      }, (uri) => seen = uri),
    );

    final result = await geocoder.geocode(
      street: 'Example 1',
      postalCode: '100',
      city: 'Tokyo',
      country: 'Giappone',
    );

    expect(seen.queryParameters.containsKey('countrycodes'), isFalse);
    expect(result?.displayLabel, 'Somewhere, Japan');
  });

  test('returns null on an error status or an empty result', () async {
    final failing = NominatimAddressGeocoder(
      client: MockClient((_) async => http.Response('', 503)),
    );
    expect(
      await failing.geocode(
        street: 'x',
        postalCode: '',
        city: 'y',
        country: 'Italia',
      ),
      isNull,
    );
    final empty = NominatimAddressGeocoder(
      client: MockClient((_) async => http.Response('[]', 200)),
    );
    expect(
      await empty.geocode(
        street: 'x',
        postalCode: '',
        city: 'y',
        country: 'Italia',
      ),
      isNull,
    );
  });
}
