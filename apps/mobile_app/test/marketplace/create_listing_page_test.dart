import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vet_app_mobile/features/location/data/device_location_service.dart';
import 'package:vet_app_mobile/features/location/domain/coordinates.dart';
import 'package:vet_app_mobile/features/marketplace/data/area_label_geocoder.dart';
import 'package:vet_app_mobile/features/marketplace/data/marketplace_repository.dart';
import 'package:vet_app_mobile/features/marketplace/domain/marketplace_listing.dart';
import 'package:vet_app_mobile/features/marketplace/presentation/pages/create_listing_page.dart';

class _FakeLocationSampler implements LocationSampler {
  const _FakeLocationSampler(this.result);

  final DeviceLocationResult result;

  @override
  Future<DeviceLocationResult> requestCurrentPosition() async => result;
}

class _FakeAreaLabelResolver implements AreaLabelResolver {
  final requested = <Coordinates>[];

  @override
  Future<String?> areaLabelOf(Coordinates approximated) async {
    requested.add(approximated);
    return 'Navigli, Milano';
  }
}

const _exact = Coordinates(latitude: 45.46423, longitude: 9.18951);
const _gps = _FakeLocationSampler(DeviceLocationResult.success(_exact));

/// The form is longer than the default 800x600 test surface, and ListView
/// only builds widgets within its viewport.
Future<void> _useTallSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(400, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

/// Pushes the page from a launcher route, like the real app does, so its
/// `pop(true)` has somewhere to go.
Future<void> _open(WidgetTester tester, CreateListingPage page) async {
  await _useTallSurface(tester);
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () =>
              Navigator.of(context).push(MaterialPageRoute<bool>(builder: (_) => page)),
          child: const Text('apri'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('apri'));
  await tester.pumpAndSettle();
}

Future<void> _pickCategory(WidgetTester tester, String label) async {
  await tester.tap(find.byType(DropdownButtonFormField<ListingCategory>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('publishing saves a rounded position and the zone name, never the exact point', (
    tester,
  ) async {
    final repository = MarketplaceRepository.inMemory(const []);
    final resolver = _FakeAreaLabelResolver();
    await _open(
      tester,
      CreateListingPage(
        locationSampler: _gps,
        areaLabelResolver: resolver,
        repository: repository,
        currentOwnerId: 'seller-1',
      ),
    );

    // The zone is suggested automatically as soon as the page opens.
    expect(find.text('Navigli, Milano'), findsOneWidget);
    // Only the rounded point is sent to the geocoding service.
    expect(resolver.requested, [const Coordinates(latitude: 45.46, longitude: 9.19)]);

    await tester.enterText(find.widgetWithText(TextFormField, 'Titolo'), 'Guinzaglio test');
    await _pickCategory(tester, 'Guinzagli, collari e pettorine');
    await tester.tap(find.text('Come nuovo'));
    await tester.tap(find.text('Cane'));
    await tester.enterText(find.widgetWithText(TextFormField, 'Prezzo in €'), '12,50');
    await tester.tap(find.text('Pubblica annuncio'));
    await tester.pumpAndSettle();

    final created = (await repository.loadActiveListings()).single;
    expect(created.title, 'Guinzaglio test');
    expect(created.ownerId, 'seller-1');
    expect(created.category, ListingCategory.leashesCollars);
    expect(created.condition, ListingCondition.likeNew);
    expect(created.species, [ListingSpecies.dog]);
    expect(created.priceCents, 1250);
    expect(created.location, const Coordinates(latitude: 45.46, longitude: 9.19));
    expect(created.cityLabel, 'Navigli, Milano');
    // Back on the launcher route.
    expect(find.text('apri'), findsOneWidget);
  });

  testWidgets('"In regalo" hides the price and saves no price', (tester) async {
    final repository = MarketplaceRepository.inMemory(const []);
    await _open(
      tester,
      CreateListingPage(
        locationSampler: _gps,
        areaLabelResolver: _FakeAreaLabelResolver(),
        repository: repository,
      ),
    );

    await tester.enterText(find.widgetWithText(TextFormField, 'Titolo'), 'Ciotole');
    await _pickCategory(tester, 'Ciotole e alimentazione');
    await tester.tap(find.text('Tutte le specie'));
    await tester.tap(find.text('In regalo'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'Prezzo in €'), findsNothing);

    await tester.tap(find.text('Pubblica annuncio'));
    await tester.pumpAndSettle();

    final created = (await repository.loadActiveListings()).single;
    expect(created.isGift, isTrue);
    expect(created.species, [ListingSpecies.allSpecies]);
  });

  testWidgets('a location failure blocks submission with a visible error', (tester) async {
    final repository = MarketplaceRepository.inMemory(const []);
    await _open(
      tester,
      CreateListingPage(
        locationSampler: const _FakeLocationSampler(
          DeviceLocationResult.failure(LocationRequestFailure.permissionDenied),
        ),
        areaLabelResolver: _FakeAreaLabelResolver(),
        repository: repository,
      ),
    );

    await tester.enterText(find.widgetWithText(TextFormField, 'Titolo'), 'Senza posizione');
    await _pickCategory(tester, 'Giochi');
    await tester.tap(find.text('Gatto'));
    await tester.tap(find.text('In regalo'));
    await tester.tap(find.text('Pubblica annuncio'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Non riesco a rilevare la tua posizione'), findsOneWidget);
    expect(find.text('Nuovo annuncio'), findsOneWidget);
    expect(await repository.loadActiveListings(), isEmpty);
  });

  testWidgets('category, species and a valid price are required', (tester) async {
    final repository = MarketplaceRepository.inMemory(const []);
    await _open(
      tester,
      CreateListingPage(
        locationSampler: _gps,
        areaLabelResolver: _FakeAreaLabelResolver(),
        repository: repository,
      ),
    );

    await tester.enterText(find.widgetWithText(TextFormField, 'Titolo'), 'Ciotola test');
    await tester.enterText(find.widgetWithText(TextFormField, 'Prezzo in €'), '-5');
    await tester.tap(find.text('Pubblica annuncio'));
    await tester.pumpAndSettle();

    expect(find.text('Scegli una categoria'), findsOneWidget);
    expect(find.text('Indica per quali animali è, oppure "Tutte le specie"'), findsOneWidget);
    expect(find.text('Il prezzo non può essere negativo'), findsOneWidget);
    expect(find.text('Nuovo annuncio'), findsOneWidget);
    expect(await repository.loadActiveListings(), isEmpty);
  });

  testWidgets('editing prefills the form and keeps the listing position', (tester) async {
    final now = DateTime(2026, 10, 1);
    final existing = MarketplaceListing(
      id: 'listing-1',
      ownerId: 'seller-1',
      title: 'Trasportino',
      category: ListingCategory.kennelsCarriers,
      condition: ListingCondition.good,
      priceCents: 2000,
      species: const [ListingSpecies.cat],
      location: const Coordinates(latitude: 45.48, longitude: 9.21),
      cityLabel: 'Città Studi, Milano',
      createdAt: now,
      updatedAt: now,
    );
    final repository = MarketplaceRepository.inMemory([existing]);
    await _open(
      tester,
      CreateListingPage(
        existing: existing,
        locationSampler: _gps,
        areaLabelResolver: _FakeAreaLabelResolver(),
        repository: repository,
        currentOwnerId: 'seller-1',
      ),
    );

    expect(find.text('Modifica annuncio'), findsOneWidget);
    expect(find.text('Trasportino'), findsOneWidget);
    expect(find.text('20,00'), findsOneWidget);
    expect(find.text('Città Studi, Milano'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Titolo'), 'Trasportino grande');
    await tester.tap(find.text('Salva modifiche'));
    await tester.pumpAndSettle();

    final saved = (await repository.loadActiveListings()).single;
    expect(saved.title, 'Trasportino grande');
    expect(saved.location, existing.location);
    expect(saved.cityLabel, 'Città Studi, Milano');
    expect(saved.createdAt, existing.createdAt);
  });

  testWidgets('saving an edit as someone else shows the permission error', (tester) async {
    final now = DateTime(2026, 10, 1);
    final existing = MarketplaceListing(
      id: 'listing-1',
      ownerId: 'seller-1',
      title: 'Trasportino',
      category: ListingCategory.kennelsCarriers,
      condition: ListingCondition.good,
      priceCents: 2000,
      species: const [ListingSpecies.cat],
      location: const Coordinates(latitude: 45.48, longitude: 9.21),
      createdAt: now,
      updatedAt: now,
    );
    final repository = MarketplaceRepository.inMemory([existing]);
    await _open(
      tester,
      CreateListingPage(
        existing: existing,
        locationSampler: _gps,
        areaLabelResolver: _FakeAreaLabelResolver(),
        repository: repository,
        currentOwnerId: 'intruder',
      ),
    );

    await tester.tap(find.text('Salva modifiche'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Solo chi ha pubblicato'), findsOneWidget);
    expect((await repository.loadActiveListings()).single.title, 'Trasportino');
  });

  testWidgets('"Tutte le specie" and single species exclude each other', (tester) async {
    await _open(
      tester,
      CreateListingPage(
        locationSampler: _gps,
        areaLabelResolver: _FakeAreaLabelResolver(),
        repository: MarketplaceRepository.inMemory(const []),
      ),
    );
    bool selected(String label) =>
        tester.widget<FilterChip>(find.widgetWithText(FilterChip, label)).selected;

    await tester.tap(find.text('Cane'));
    await tester.tap(find.text('Gatto'));
    await tester.pump();
    expect(selected('Cane') && selected('Gatto'), isTrue);

    await tester.tap(find.text('Tutte le specie'));
    await tester.pump();
    expect(selected('Tutte le specie'), isTrue);
    expect(selected('Cane') || selected('Gatto'), isFalse);

    await tester.tap(find.text('Pesce'));
    await tester.pump();
    expect(selected('Pesce'), isTrue);
    expect(selected('Tutte le specie'), isFalse);
  });
}
