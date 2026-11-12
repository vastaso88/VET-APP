import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vet_app_mobile/features/location/domain/coordinates.dart';
import 'package:vet_app_mobile/features/marketplace/data/marketplace_repository.dart';
import 'package:vet_app_mobile/features/marketplace/domain/listing_filters.dart';
import 'package:vet_app_mobile/features/marketplace/domain/marketplace_listing.dart';
import 'package:vet_app_mobile/shared/config/app_runtime_config.dart';
import 'package:vet_app_mobile/shared/config/app_runtime_config_loader.dart';

import '../territory/territory_test_helpers.dart';

const _me = Coordinates(latitude: 45.8081, longitude: 9.0852);

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

MarketplaceRepository _repository(MockClient client) => MarketplaceRepository(
      httpClient: client,
      configLoader: const _ConfigWithBackend(),
      tokenProvider: () => 'jwt',
    );

/// What the backend sends an owner without a plan: the first look only.
Map<String, dynamic> _limitedRow(String id, {double distanceKm = 2.5}) => {
      'id': id,
      'title': 'Trasportino',
      'price_cents': 2500,
      'photo_urls': ['https://example.com/a.jpg'],
      'city_label': 'Milano',
      'country': 'IT',
      'distance_km': distanceKm,
      'is_mine': false,
    };

MockClient _limitedBackend() => MockClient((request) async {
      final path = request.url.path;
      if (path == '/marketplace/listings') {
        return http.Response(
          jsonEncode({
            'listings': [_limitedRow('ad-near', distanceKm: 2.5), _limitedRow('ad-far', distanceKm: 40)],
            'context': {'radius_km': 10.0, 'limited': true},
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (path == '/marketplace/listings/ad-near') {
        return http.Response(
          jsonEncode({'listing': _limitedRow('ad-near'), 'limited': true}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response('{"code":"subscription_required"}', 402);
    });

void main() {
  // A 402 sends the owner to the paywall through the app's navigator key,
  // which needs the widgets binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async => useLanguageVariant('it'));
  tearDown(resetTerritoryForTest);

  group('an ad read by an owner without a plan', () {
    test('the list keeps the first look and marks the ads as limited', () async {
      final listings = await _repository(_limitedBackend())
          .loadNearbyListings(center: _me, radiusKm: 50);

      expect(listings, hasLength(2));
      final first = listings.first;
      expect(first.isLimited, isTrue);
      expect(first.title, 'Trasportino');
      expect(first.priceCents, 2500);
      expect(first.photoUrls, ['https://example.com/a.jpg']);
      expect(first.cityLabel, 'Milano');
      expect(first.description, isNull);
      expect(first.ownerId, isEmpty, reason: 'the seller is never sent');
    });

    test('the distance is the one the backend measured, in metres', () async {
      final listings = await _repository(_limitedBackend())
          .loadNearbyListings(center: _me, radiusKm: 50);

      expect(listings.first.serverDistanceMeters, 2500);
    });

    test('the radius filter works on that distance, since the position is withheld', () async {
      final listings = await _repository(_limitedBackend())
          .loadNearbyListings(center: _me, radiusKm: 50);

      final matches = applyListingFilter(
        listings,
        const ListingFilter(maxDistanceKm: 10),
        reference: _me,
      );

      expect(matches.map((m) => m.listing.id), ['ad-near']);
      expect(matches.single.distanceMeters, 2500);
    });

    test('category and species filters do not drop ads that carry neither', () async {
      final listings = await _repository(_limitedBackend())
          .loadNearbyListings(center: _me, radiusKm: 50);

      final matches = applyListingFilter(
        listings,
        const ListingFilter(category: ListingCategory.toys, maxDistanceKm: 100),
        reference: _me,
      );

      expect(matches, hasLength(2));
    });

    test('the detail is read the same way', () async {
      final listing = await _repository(_limitedBackend()).loadListing('ad-near');

      expect(listing, isNotNull);
      expect(listing!.isLimited, isTrue);
      expect(listing.description, isNull);
    });

    test('a full ad is not marked as limited', () async {
      final client = MockClient((request) async => http.Response(
            jsonEncode({
              'listings': [
                {
                  'id': 'ad-full',
                  'title': 'Palla',
                  'description': 'Poco usata',
                  'category': 'toys',
                  'condition': 'good',
                  'price_cents': 400,
                  'photo_urls': <String>[],
                  'target_species': ['dog'],
                  'latitude': 45.81,
                  'longitude': 9.09,
                  'city_label': 'Como',
                  'country': 'IT',
                  'status': 'active',
                  'report_count': 0,
                  'created_at': '2026-10-26T10:00:00Z',
                  'updated_at': '2026-10-26T10:00:00Z',
                  'distance_km': 0.2,
                },
              ],
              'context': {'radius_km': 10.0, 'limited': false},
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ));

      final listings = await _repository(client).loadNearbyListings(center: _me, radiusKm: 50);

      expect(listings.single.isLimited, isFalse);
      expect(listings.single.serverDistanceMeters, isNull);
      expect(listings.single.description, 'Poco usata');
    });
  });

  group('the actions answer 402 for an owner without a plan', () {
    test('reporting an ad is refused with a message the owner can read', () async {
      final repository = _repository(_limitedBackend());
      final listing = (await repository.loadListing('ad-near'))!;

      await expectLater(
        repository.reportListing(listing, 'spam'),
        throwsA(isA<ListingRejectedException>()),
      );
    });

    test('reporting goes through the backend, which tells nothing about the ad', () async {
      late http.Request seen;
      final client = MockClient((request) async {
        seen = request;
        return http.Response(jsonEncode({'ok': true}), 200);
      });
      final repository = _repository(client);
      final now = DateTime(2026, 10, 26);
      final listing = MarketplaceListing(
        id: 'ad-9',
        ownerId: 'seller',
        title: 'Palla',
        category: ListingCategory.toys,
        condition: ListingCondition.good,
        location: const Coordinates(latitude: 45.8, longitude: 9.0),
        createdAt: now,
        updatedAt: now,
      );

      final updated = await repository.reportListing(listing, 'scam');

      expect(seen.method, 'POST');
      expect(seen.url.path, '/marketplace/listings/ad-9/report');
      expect(jsonDecode(seen.body), {'reason': 'scam'});
      expect(updated!.reportCount, 0);
      expect(updated.status, ListingStatus.active);
    });

    test('an ad no longer open answers like a missing one', () async {
      final repository = _repository(MockClient((_) async => http.Response('{}', 404)));
      final now = DateTime(2026, 11, 9);
      final listing = MarketplaceListing(
        id: 'ad-gone',
        ownerId: 'seller',
        title: 'Palla',
        category: ListingCategory.toys,
        condition: ListingCondition.good,
        location: const Coordinates(latitude: 45.8, longitude: 9.0),
        createdAt: now,
        updatedAt: now,
      );

      await expectLater(
        repository.reportListing(listing, 'spam'),
        throwsA(
          isA<ListingRejectedException>().having(
            (e) => e.message,
            'message',
            'Questo annuncio non è più disponibile.',
          ),
        ),
      );
    });
  });
}
