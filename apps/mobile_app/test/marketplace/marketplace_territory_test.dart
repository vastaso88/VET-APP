import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/location/data/device_location_service.dart';
import 'package:vet_app_mobile/features/location/domain/coordinates.dart';
import 'package:vet_app_mobile/features/marketplace/data/area_label_geocoder.dart';
import 'package:vet_app_mobile/features/marketplace/data/marketplace_repository.dart';
import 'package:vet_app_mobile/features/marketplace/domain/marketplace_listing.dart';
import 'package:vet_app_mobile/features/marketplace/presentation/marketplace_labels.dart';
import 'package:vet_app_mobile/features/marketplace/presentation/pages/create_listing_page.dart';
import 'package:vet_app_mobile/features/territory/domain/territory.dart';

import '../territory/territory_test_helpers.dart';

const _me = Coordinates(latitude: 45.46, longitude: 9.19);

MarketplaceListing _listing(String id, {String country = 'IT', double kmNorth = 1}) {
  final now = DateTime(2026, 10, 14);
  return MarketplaceListing(
    id: id,
    ownerId: 'seller',
    title: id,
    category: ListingCategory.toys,
    condition: ListingCondition.good,
    species: const [ListingSpecies.dog],
    country: country,
    location: Coordinates(latitude: _me.latitude + kmNorth / 111.2, longitude: _me.longitude),
    createdAt: now,
    updatedAt: now,
  );
}

class _FakeLocationSampler implements LocationSampler {
  const _FakeLocationSampler();

  @override
  Future<DeviceLocationResult> requestCurrentPosition() async =>
      const DeviceLocationResult.success(Coordinates(latitude: 45.46423, longitude: 9.18951));
}

class _FakeAreaLabelResolver implements AreaLabelResolver {
  @override
  Future<String?> areaLabelOf(Coordinates approximated) async => 'Zona';
}

Future<void> _openCreate(WidgetTester tester, MarketplaceRepository repository) async {
  await tester.binding.setSurfaceSize(const Size(400, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<bool>(
              builder: (_) => CreateListingPage(
                locationSampler: const _FakeLocationSampler(),
                areaLabelResolver: _FakeAreaLabelResolver(),
                repository: repository,
                currentOwnerId: 'seller-1',
              ),
            ),
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  tearDown(resetTerritoryForTest);

  group('price and currency per country', () {
    test('each country writes its own currency symbol', () async {
      await useLanguageVariant('en-GB');
      expect(listingPriceLabel(1250, country: 'GB'), '£12.50');
      await useLanguageVariant('en-US');
      expect(listingPriceLabel(1250, country: 'US'), r'$12.50');
      await useLanguageVariant('en-AU');
      expect(listingPriceLabel(1250, country: 'AU'), r'A$12.50');
      await useLanguageVariant('it');
      expect(listingPriceLabel(1250, country: 'IT'), contains('€'));
      expect(listingPriceLabel(1250, country: 'IT'), contains('12,50'));
    });

    test('the price follows the country of the ad, not of the reader', () async {
      await useLanguageVariant('en-GB');
      expect(listingPriceLabel(1000, country: 'US'), startsWith(r'$'));
      expect(listingPriceLabel(null), 'Free gift');
    });

    test('the price field names the currency of the owner', () async {
      await useLanguageVariant('en-AU');
      expect(listingPriceFieldLabel(), r'Price (A$)');
      await useLanguageVariant('it');
      expect(listingPriceFieldLabel(), 'Prezzo in €');
    });
  });

  group('repository radius rule', () {
    test('a search without a valid radius is refused, a valid one is served', () async {
      final repository = MarketplaceRepository.inMemory([_listing('a')]);

      for (final bad in [0.0, 0.5, -5.0, 300.1, 500.0, double.nan]) {
        await expectLater(
          repository.loadNearbyListings(center: _me, radiusKm: bad),
          throwsA(isA<InvalidListingRadiusException>()),
          reason: '$bad km',
        );
      }
      expect(
        await repository.loadNearbyListings(center: _me, radiusKm: marketplaceMaxRadiusKm),
        hasLength(1),
      );
    });

    test('only the ads of the owner\'s country come back, never the others', () async {
      final repository = MarketplaceRepository.inMemory([
        _listing('it-ad'),
        _listing('fr-ad', country: 'FR'),
      ]);

      expect((await repository.loadNearbyListings(center: _me, radiusKm: 10)).map((l) => l.id),
          ['it-ad']);
      expect(
        (await repository.loadNearbyListings(center: _me, radiusKm: 10, country: 'FR'))
            .map((l) => l.id),
        ['fr-ad'],
      );
      expect(await repository.loadNearbyListings(center: _me, radiusKm: 10, country: 'DE'), isEmpty);
    });
  });

  group('no live animals', () {
    testWidgets('in Spain publishing needs the confirmation, then it works', (tester) async {
      await useLanguageVariant('es');
      final repository = MarketplaceRepository.inMemory(const []);
      await _openCreate(tester, repository);

      expect(find.text('En tu país el mercadillo no admite anuncios de animales vivos: '
          'solo productos y servicios para animales.'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Título'), 'Correa');
      await tester.tap(find.byType(DropdownButtonFormField<ListingCategory>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Correas, collares y arneses').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Perro'));
      await tester.enterText(find.widgetWithText(TextFormField, 'Precio (€)'), '5');

      await tester.tap(find.text('Publicar anuncio'));
      await tester.pumpAndSettle();
      expect(find.text('Confirma que el anuncio no ofrece un animal vivo'), findsOneWidget);
      expect(await repository.loadActiveListings(), isEmpty);

      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Publicar anuncio'));
      await tester.pumpAndSettle();

      final created = (await repository.loadActiveListings()).single;
      expect(created.country, 'ES', reason: 'the ad carries the country of its seller');
      expect(created.title, 'Correa');
    });

    testWidgets('in Italy there is no such confirmation', (tester) async {
      await useLanguageVariant('it');
      expect(currentTerritory().liveAnimalListingsAllowed, isTrue);
      await _openCreate(tester, MarketplaceRepository.inMemory(const []));

      expect(find.byType(CheckboxListTile), findsNothing);
    });
  });
}
