import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vet_app_mobile/features/location/data/address_geocoder.dart';
import 'package:vet_app_mobile/features/location/domain/coordinates.dart';
import 'package:vet_app_mobile/features/nearby_places/data/reverse_geocoder.dart';
import 'package:vet_app_mobile/shared/config/app_runtime_config.dart';
import 'package:vet_app_mobile/shared/config/app_runtime_config_loader.dart';

class _FakeConfigLoader extends AppRuntimeConfigLoader {
  const _FakeConfigLoader(this.apiBaseUrl);

  final String apiBaseUrl;

  @override
  AppRuntimeConfig load() => AppRuntimeConfig(
        environment: AppEnvironment.development,
        appName: 'test',
        apiBaseUrl: apiBaseUrl,
        supabaseUrl: '',
        supabaseAnonKey: '',
        logLevel: 'INFO',
        enableTelemetry: false,
      );
}

const _backend = _FakeConfigLoader('https://api.esempio.example');
String? _token() => 'token-di-prova';

NominatimAddressGeocoder _geocoder(http.Client client) =>
    NominatimAddressGeocoder(client: client, configLoader: _backend, accessToken: _token);

void main() {
  http.Client backendAnswering(
    Map<String, dynamic> match,
    void Function(http.Request request) onRequest,
  ) {
    return MockClient((request) async {
      onRequest(request);
      return http.Response(
        jsonEncode({
          'results': [match],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
  }

  test('asks the backend, never Nominatim, with the address in the body', () async {
    late http.Request seen;
    final geocoder = _geocoder(
      backendAnswering({
        'latitude': 41.88,
        'longitude': -87.63,
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
      }, (request) => seen = request),
    );

    final result = await geocoder.geocode(
      street: '12 Example St',
      postalCode: '62704',
      city: 'Springfield',
      country: 'United States',
    );

    expect(seen.method, 'POST');
    expect(seen.url.toString(), 'https://api.esempio.example/geocoding/search');
    expect(seen.url.hasQuery, isFalse);
    expect(seen.headers['Authorization'], 'Bearer token-di-prova');
    final body = jsonDecode(seen.body) as Map<String, dynamic>;
    expect(body['country_code'], 'us');
    expect(body['query'], '12 Example St, Springfield, 62704, United States');
    expect(result?.displayLabel, '12 Example St, Springfield, IL 62704');
    expect(result?.coordinates.latitude, 41.88);
  });

  test('sends no country for a country the radar does not know', () async {
    late http.Request seen;
    final geocoder = _geocoder(
      backendAnswering({
        'latitude': 35.68,
        'longitude': 139.65,
        'display_name': 'Somewhere, Japan',
        'address': <String, dynamic>{},
      }, (request) => seen = request),
    );

    final result = await geocoder.geocode(
      street: 'Example 1',
      postalCode: '100',
      city: 'Tokyo',
      country: 'Giappone',
    );

    expect((jsonDecode(seen.body) as Map<String, dynamic>).containsKey('country_code'), isFalse);
    expect(result?.displayLabel, 'Somewhere, Japan');
  });

  test('returns null on an error status, an empty result, or without a session', () async {
    Future<GeocodedAddress?> run(NominatimAddressGeocoder geocoder) => geocoder.geocode(
          street: 'x',
          postalCode: '',
          city: 'y',
          country: 'Italia',
        );

    expect(await run(_geocoder(MockClient((_) async => http.Response('', 503)))), isNull);
    expect(
      await run(_geocoder(MockClient((_) async => http.Response('{"results": []}', 200)))),
      isNull,
    );
    var called = false;
    final signedOut = NominatimAddressGeocoder(
      client: MockClient((_) async {
        called = true;
        return http.Response('{}', 200);
      }),
      configLoader: _backend,
      accessToken: () => null,
    );
    expect(await run(signedOut), isNull);
    expect(called, isFalse);
  });

  test('the reverse geocoder asks the backend too and formats the address', () async {
    late http.Request seen;
    final reverse = ReverseGeocoder(
      client: MockClient((request) async {
        seen = request;
        return http.Response(
          jsonEncode({
            'result': {
              'latitude': 45.4642,
              'longitude': 9.19,
              'display_name': 'unused',
              'address': {
                'road': 'Via Esempio',
                'house_number': '10',
                'city': 'Milano',
                'country_code': 'it',
              },
            },
          }),
          200,
        );
      }),
      configLoader: _backend,
      accessToken: _token,
    );

    final label = await reverse.addressOf(const Coordinates(latitude: 45.4642, longitude: 9.19));

    expect(seen.url.toString(), 'https://api.esempio.example/geocoding/reverse');
    expect(seen.url.hasQuery, isFalse);
    expect((jsonDecode(seen.body) as Map<String, dynamic>)['zoom'], 18);
    expect(label, 'Via Esempio 10, Milano');
  });
}
