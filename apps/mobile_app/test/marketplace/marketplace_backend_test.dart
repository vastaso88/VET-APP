import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vet_app_mobile/features/location/domain/coordinates.dart';
import 'package:vet_app_mobile/features/marketplace/data/marketplace_repository.dart';
import 'package:vet_app_mobile/features/marketplace/domain/marketplace_listing.dart';
import 'package:vet_app_mobile/features/marketplace/presentation/marketplace_labels.dart';
import 'package:vet_app_mobile/shared/config/app_runtime_config.dart';
import 'package:vet_app_mobile/shared/config/app_runtime_config_loader.dart';

import '../territory/territory_test_helpers.dart';

const _me = Coordinates(latitude: 45.8081, longitude: 9.0852); // Como

class _ConfigWithBackend extends AppRuntimeConfigLoader {
  const _ConfigWithBackend();

  @override
  AppRuntimeConfig load() => const AppRuntimeConfig(
        environment: AppEnvironment.development,
        appName: 'test',
        apiBaseUrl: 'https://api.test',
        supabaseUrl: '',
        supabaseAnonKey: '',
        logLevel: 'INFO',
        enableTelemetry: false,
      );
}

MarketplaceListing _listing({
  String title = 'Cuccia per cuccioli',
  String? description,
  String country = 'IT',
}) {
  final now = DateTime(2026, 10, 26);
  return MarketplaceListing(
    id: 'listing-1',
    ownerId: 'seller-1',
    title: title,
    description: description,
    category: ListingCategory.kennelsCarriers,
    condition: ListingCondition.good,
    priceCents: 2500,
    species: const [ListingSpecies.dog],
    country: country,
    location: const Coordinates(latitude: 45.46, longitude: 9.19),
    cityLabel: 'Milano',
    createdAt: now,
    updatedAt: now,
  );
}

Map<String, dynamic> _row(String id, {String country = 'IT', String city = 'Milano'}) => {
      'id': id,
      'owner_id': 'seller-1',
      'title': 'Palla',
      'description': null,
      'category': 'toys',
      'condition': 'good',
      'price_cents': 4000,
      'photo_urls': <String>[],
      'target_species': ['dog'],
      'latitude': 46.0,
      'longitude': 8.95,
      'city_label': city,
      'country': country,
      'status': 'active',
      'report_count': 0,
      'created_at': '2026-10-26T10:00:00Z',
      'updated_at': '2026-10-26T10:00:00Z',
    };

MarketplaceRepository _repository(MockClient client, {String? token = 'jwt'}) =>
    MarketplaceRepository(
      httpClient: client,
      configLoader: const _ConfigWithBackend(),
      tokenProvider: () => token,
    );

void main() {
  setUp(() async => useLanguageVariant('it'));
  tearDown(resetTerritoryForTest);

  group('reading goes through the backend', () {
    test('a search asks GET /marketplace/listings with the radius and no country', () async {
      late http.Request seen;
      final repository = _repository(MockClient((request) async {
        seen = request;
        return http.Response(
          jsonEncode({
            'listings': [_row('lugano', country: 'CH', city: 'Lugano'), _row('como')],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }));

      final found = await repository.loadNearbyListings(center: _me, radiusKm: 25);

      expect(seen.method, 'GET');
      expect(seen.url.path, '/marketplace/listings');
      expect(seen.url.queryParameters['radius_km'], '25.0');
      expect(seen.url.queryParameters.containsKey('country'), isFalse);
      expect(seen.headers['Authorization'], 'Bearer jwt');
      expect(found.map((l) => l.country), ['CH', 'IT'], reason: 'ads across the border are kept');
    });

    test('a radius outside 1-300 km is refused before any request', () async {
      var requests = 0;
      final repository = _repository(MockClient((_) async {
        requests++;
        return http.Response('{}', 200);
      }));

      for (final bad in [0.0, 0.5, 301.0, double.nan]) {
        await expectLater(
          repository.loadNearbyListings(center: _me, radiusKm: bad),
          throwsA(isA<InvalidListingRadiusException>()),
        );
      }
      expect(requests, 0);
    });

    test('one ad by id comes from GET /marketplace/listings/{id}; unknown is null', () async {
      final repository = _repository(MockClient((request) async {
        if (request.url.path.endsWith('/listing-1')) {
          return http.Response(jsonEncode({'listing': _row('listing-1')}), 200);
        }
        return http.Response('{"detail":"Annuncio non trovato."}', 404);
      }));

      expect((await repository.loadListing('listing-1'))?.id, 'listing-1');
      expect(await repository.loadListing('missing'), isNull);
    });

    test('without a session nothing is asked of the backend: the local list answers', () async {
      var requests = 0;
      final repository = MarketplaceRepository(
        httpClient: MockClient((_) async {
          requests++;
          return http.Response('{}', 200);
        }),
        configLoader: const _ConfigWithBackend(),
        tokenProvider: () => null,
      );

      final found = await repository.loadNearbyListings(center: _me, radiusKm: 25);

      expect(requests, 0);
      expect(found, isNotEmpty, reason: 'the demo seed');
    });
  });

  group('writing goes through the backend', () {
    test('an ad for objects is POSTed with its snapped place and country', () async {
      late http.Request seen;
      final repository = _repository(MockClient((request) async {
        seen = request;
        return http.Response(jsonEncode({'listing': _row('new')}), 200);
      }));

      await repository.createListing(_listing(country: 'CH'));

      expect(seen.method, 'POST');
      expect(seen.url.path, '/marketplace/listings');
      final body = jsonDecode(seen.body) as Map<String, dynamic>;
      expect(body['title'], 'Cuccia per cuccioli');
      expect(body['country'], 'CH');
      expect(body['latitude'], 45.46);
      expect(body.containsKey('status'), isFalse, reason: 'the backend decides the status');
      expect(body.containsKey('owner_id'), isFalse, reason: 'the backend knows the author');
    });

    test('an ad that offers an animal is stopped in the app, nothing is sent', () async {
      var requests = 0;
      final repository = _repository(MockClient((_) async {
        requests++;
        return http.Response('{}', 200);
      }));

      await expectLater(
        repository.createListing(_listing(title: 'Vendo cuccioli')),
        throwsA(isA<ListingRejectedException>().having(
          (e) => e.message,
          'message',
          'Sul Mercatino si vendono solo oggetti per animali, non animali.',
        )),
      );
      await expectLater(
        repository.updateListing(_listing(description: 'regalo gattini'), requesterId: 'seller-1'),
        throwsA(isA<ListingRejectedException>()),
      );
      expect(requests, 0);
    });

    test('the backend refusal reaches the owner in their own language', () async {
      await useLanguageVariant('en-GB');
      final repository = _repository(MockClient((_) async => http.Response(
            jsonEncode({'detail': 'Sul Mercatino si vendono solo oggetti per animali, non animali.'}),
            400,
          )));

      await expectLater(
        repository.createListing(_listing()),
        throwsA(isA<ListingRejectedException>().having(
          (e) => e.message,
          'message',
          'Only items for animals are sold on the marketplace, not animals.',
        )),
      );
    });

    test('an edit is a PUT of the ad, only for its author', () async {
      late http.Request seen;
      final repository = _repository(MockClient((request) async {
        seen = request;
        return http.Response(jsonEncode({'listing': _row('listing-1')}), 200);
      }));

      await repository.updateListing(_listing(title: 'Cuccia nuova'), requesterId: 'seller-1');
      expect(seen.method, 'PUT');
      expect(seen.url.path, '/marketplace/listings/listing-1');

      await expectLater(
        repository.updateListing(_listing(), requesterId: 'someone-else'),
        throwsA(isA<ListingPermissionException>()),
      );
    });
  });

  group('the seller flag', () {
    test('a flag for each country, nothing for garbage', () {
      expect(countryFlag('CH'), '\u{1F1E8}\u{1F1ED}');
      expect(countryFlag('it'), '\u{1F1EE}\u{1F1F9}');
      expect(countryFlag(''), '');
      expect(countryFlag('ITA'), '');
    });

    test('only an ad from another country gets its flag in front of the city', () {
      expect(listingPlaceLabel(_listing()), 'Milano');
      expect(listingPlaceLabel(_listing(country: 'CH')), '\u{1F1E8}\u{1F1ED} Milano');
      expect(isForeignListing(_listing(country: 'CH')), isTrue);
      expect(isForeignListing(_listing()), isFalse);
    });

    test('the price of a Swiss ad is in francs, not converted', () {
      expect(listingPriceLabel(4000, country: 'CH'), contains('CHF'));
      expect(listingPriceLabel(4000, country: 'CH'), contains('40'));
    });
  });
}
