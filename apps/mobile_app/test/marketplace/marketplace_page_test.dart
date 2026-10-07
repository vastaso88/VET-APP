import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vet_app_mobile/features/location/domain/coordinates.dart';
import 'package:vet_app_mobile/features/marketplace/data/marketplace_repository.dart';
import 'package:vet_app_mobile/features/marketplace/domain/marketplace_listing.dart';
import 'package:vet_app_mobile/features/marketplace/presentation/pages/listing_detail_page.dart';
import 'package:vet_app_mobile/features/marketplace/presentation/pages/marketplace_page.dart';

const _me = Coordinates(latitude: 45.46, longitude: 9.19);

MarketplaceListing _listing(
  String title,
  ListingCategory category, {
  required double kmNorth,
  String ownerId = 'seller',
  List<ListingSpecies> species = const [ListingSpecies.dog],
}) {
  final now = DateTime(2026, 10, 7);
  return MarketplaceListing(
    id: title,
    ownerId: ownerId,
    title: title,
    category: category,
    condition: ListingCondition.good,
    priceCents: 1000,
    species: species,
    location: Coordinates(latitude: _me.latitude + kmNorth / 111.2, longitude: _me.longitude),
    createdAt: now,
    updatedAt: now,
  );
}

List<MarketplaceListing> _listings() => [
      _listing('Pallina vicina', ListingCategory.toys, kmNorth: 1),
      _listing('Collare a 4 km', ListingCategory.leashesCollars, kmNorth: 4),
      _listing('Gioco a 8 km', ListingCategory.toys,
          kmNorth: 8, species: const [ListingSpecies.cat]),
      _listing(
        'Gabbia a 20 km',
        ListingCategory.cagesAviaries,
        kmNorth: 20,
        species: const [ListingSpecies.allSpecies],
      ),
      _listing('Gioco lontano', ListingCategory.toys, kmNorth: 60),
    ];

/// Wide: test text renders as square glyphs, so the chip rows are long.
Future<void> _pumpPage(WidgetTester tester, {Coordinates? reference}) async {
  await tester.binding.setSurfaceSize(const Size(1400, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: MarketplacePage(
        repository: MarketplaceRepository.inMemory(_listings()),
        referenceLoader: () async => reference,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('with a position, 25 km is preselected', (tester) async {
    await _pumpPage(tester, reference: _me);

    expect(find.text('Pallina vicina'), findsOneWidget);
    expect(find.text('Gabbia a 20 km'), findsOneWidget);
    expect(find.text('Gioco lontano'), findsNothing);
    final chip = tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '25 km'));
    expect(chip.selected, isTrue);
  });

  testWidgets('the distance filter narrows the list', (tester) async {
    await _pumpPage(tester, reference: _me);

    await tester.tap(find.widgetWithText(ChoiceChip, '5 km'));
    await tester.pumpAndSettle();
    expect(find.text('Pallina vicina'), findsOneWidget);
    expect(find.text('Collare a 4 km'), findsOneWidget);
    expect(find.text('Gioco a 8 km'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, '2 km'));
    await tester.pumpAndSettle();
    expect(find.text('Pallina vicina'), findsOneWidget);
    expect(find.text('Collare a 4 km'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Ovunque'));
    await tester.pumpAndSettle();
    expect(find.text('Gioco lontano'), findsOneWidget);
  });

  testWidgets('category and distance filters combine', (tester) async {
    await _pumpPage(tester, reference: _me);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Giochi'));
    await tester.tap(find.widgetWithText(ChoiceChip, '10 km'));
    await tester.pumpAndSettle();

    expect(find.text('Pallina vicina'), findsOneWidget);
    expect(find.text('Gioco a 8 km'), findsOneWidget);
    expect(find.text('Collare a 4 km'), findsNothing);
    expect(find.text('Gioco lontano'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Guinzagli, collari e pettorine'));
    await tester.tap(find.widgetWithText(ChoiceChip, '2 km'));
    await tester.pumpAndSettle();
    expect(find.text('Nessun annuncio con questi filtri per ora.'), findsOneWidget);
  });

  testWidgets('the species filter keeps that species and items for all species', (tester) async {
    await _pumpPage(tester, reference: _me);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Gatto'));
    await tester.pumpAndSettle();

    expect(find.text('Gioco a 8 km'), findsOneWidget);
    expect(find.text('Gabbia a 20 km'), findsOneWidget);
    expect(find.text('Pallina vicina'), findsNothing);
    expect(find.text('Collare a 4 km'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Tutti gli animali'));
    await tester.pumpAndSettle();
    expect(find.text('Pallina vicina'), findsOneWidget);
  });

  testWidgets('without a position everything is shown and distance is off', (tester) async {
    await _pumpPage(tester);

    expect(find.text('Gioco lontano'), findsOneWidget);
    expect(find.textContaining('imposta la tua posizione'), findsOneWidget);
    final chip = tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '2 km'));
    expect(chip.onSelected, isNull);
  });

  testWidgets('the map button is available once listings are loaded', (tester) async {
    await _pumpPage(tester, reference: _me);
    expect(find.widgetWithText(TextButton, 'Mappa'), findsOneWidget);
  });

  group('listing detail', () {
    Future<MarketplaceRepository> pumpDetail(WidgetTester tester, String currentOwnerId) async {
      final listing = _listing('Pallina', ListingCategory.toys, kmNorth: 1, ownerId: 'seller');
      final repository = MarketplaceRepository.inMemory([listing]);
      await tester.binding.setSurfaceSize(const Size(500, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<bool>(
                  builder: (_) => ListingDetailPage(
                    listing: listing,
                    repository: repository,
                    currentOwnerId: currentOwnerId,
                  ),
                ),
              ),
              child: const Text('apri'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('apri'));
      await tester.pumpAndSettle();
      return repository;
    }

    testWidgets('the author sees edit and delete, not report', (tester) async {
      await pumpDetail(tester, 'seller');
      expect(find.text('Modifica annuncio'), findsOneWidget);
      expect(find.text('Elimina annuncio'), findsOneWidget);
      expect(find.text('Segnala annuncio'), findsNothing);
    });

    testWidgets('others only see report', (tester) async {
      await pumpDetail(tester, 'someone-else');
      expect(find.text('Modifica annuncio'), findsNothing);
      expect(find.text('Elimina annuncio'), findsNothing);
      expect(find.text('Segnala annuncio'), findsOneWidget);
    });

    testWidgets('delete asks for confirmation; cancelling keeps the listing', (tester) async {
      final repository = await pumpDetail(tester, 'seller');

      await tester.tap(find.text('Elimina annuncio'));
      await tester.pumpAndSettle();
      expect(find.text('Eliminare l\'annuncio?'), findsOneWidget);

      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();
      expect(await repository.loadActiveListings(), hasLength(1));
      expect(find.text('Elimina annuncio'), findsOneWidget);
    });

    testWidgets('confirming deletes the listing and goes back', (tester) async {
      final repository = await pumpDetail(tester, 'seller');

      await tester.tap(find.text('Elimina annuncio'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Elimina'));
      await tester.pumpAndSettle();

      expect(await repository.loadActiveListings(), isEmpty);
      expect(find.text('apri'), findsOneWidget);
    });
  });
}
