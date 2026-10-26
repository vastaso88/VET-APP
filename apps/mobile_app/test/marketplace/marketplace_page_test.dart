import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vet_app_mobile/app/shell/home_shell_page.dart';
import 'package:vet_app_mobile/features/location/domain/coordinates.dart';
import 'package:vet_app_mobile/features/marketplace/data/listing_radius_store.dart';
import 'package:vet_app_mobile/features/marketplace/data/marketplace_repository.dart';
import 'package:vet_app_mobile/features/marketplace/domain/marketplace_listing.dart';
import 'package:vet_app_mobile/features/marketplace/presentation/pages/listing_detail_page.dart';
import 'package:vet_app_mobile/features/marketplace/presentation/pages/marketplace_page.dart';

import '../territory/territory_test_helpers.dart';

const _me = Coordinates(latitude: 45.46, longitude: 9.19);

MarketplaceListing _listing(
  String title,
  ListingCategory category, {
  required double kmNorth,
  String ownerId = 'seller',
  List<ListingSpecies> species = const [ListingSpecies.dog],
  String country = 'IT',
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
    country: country,
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
      _listing('Gioco a 40 km', ListingCategory.toys, kmNorth: 40),
      _listing('Gioco lontano', ListingCategory.toys, kmNorth: 60),
      _listing('Annuncio francese', ListingCategory.toys, kmNorth: 1, country: 'FR'),
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

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ListingRadiusStore.instance.resetForTest();
  });

  testWidgets('with a position, 50 km is preselected', (tester) async {
    await _pumpPage(tester, reference: _me);

    expect(find.text('Pallina vicina'), findsOneWidget);
    expect(find.text('Gioco a 40 km'), findsOneWidget);
    expect(find.text('Gioco lontano'), findsNothing);
    final chip = tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '50 km'));
    expect(chip.selected, isTrue);
    expect(tester.widget<ChoiceChip>(find.byKey(const ValueKey('marketplace-radius-other'))).selected,
        isFalse);
  });

  testWidgets('the distance filter narrows and widens the list', (tester) async {
    await _pumpPage(tester, reference: _me);

    await tester.tap(find.widgetWithText(ChoiceChip, '10 km'));
    await tester.pumpAndSettle();
    expect(find.text('Gioco a 8 km'), findsOneWidget);
    expect(find.text('Gabbia a 20 km'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, '25 km'));
    await tester.pumpAndSettle();
    expect(find.text('Gabbia a 20 km'), findsOneWidget);
    expect(find.text('Gioco a 40 km'), findsNothing);

    // 100 km now reaches the 60 km ad too; the old 50 km ceiling is gone.
    await tester.tap(find.widgetWithText(ChoiceChip, '100 km'));
    await tester.pumpAndSettle();
    expect(find.text('Gioco lontano'), findsOneWidget);
  });

  testWidgets('there is no "everywhere" choice: 10, 25, 50, 100 km and Altro', (tester) async {
    await _pumpPage(tester, reference: _me);

    expect(find.text('Ovunque'), findsNothing);
    for (final label in ['10 km', '25 km', '50 km', '100 km']) {
      expect(find.widgetWithText(ChoiceChip, label), findsOneWidget, reason: label);
    }
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('marketplace-radius-other')),
        matching: find.text('Altro'),
      ),
      findsOneWidget,
    );
  });

  group('Altro', () {
    Future<void> enterOther(WidgetTester tester, String text) async {
      await tester.tap(find.byKey(const ValueKey('marketplace-radius-other')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('marketplace-radius-field')), text);
      await tester.tap(find.byKey(const ValueKey('marketplace-radius-confirm')));
      await tester.pumpAndSettle();
    }

    testWidgets('a typed distance filters the list, shows its value and is kept', (tester) async {
      await _pumpPage(tester, reference: _me);

      await enterOther(tester, '5');

      expect(find.text('Collare a 4 km'), findsOneWidget);
      expect(find.text('Gioco a 8 km'), findsNothing);
      final other = tester.widget<ChoiceChip>(find.byKey(const ValueKey('marketplace-radius-other')));
      expect(other.selected, isTrue);
      expect(find.widgetWithText(ChoiceChip, 'Altro: 5 km'), findsOneWidget);
      expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '50 km')).selected, isFalse);
      expect((await SharedPreferences.getInstance()).getInt('vet_app.marketplace_radius_km'), 5);
    });

    testWidgets('the choice is still there when the page is opened again', (tester) async {
      await _pumpPage(tester, reference: _me);
      await enterOther(tester, '5');

      // A fresh start of the app: the store forgets, the phone remembers.
      ListingRadiusStore.instance.resetForTest();
      await tester.pumpWidget(const SizedBox());
      await _pumpPage(tester, reference: _me);

      expect(find.widgetWithText(ChoiceChip, 'Altro: 5 km'), findsOneWidget);
      expect(find.text('Gioco a 8 km'), findsNothing);
      expect(find.text('Collare a 4 km'), findsOneWidget);
    });

    testWidgets('a quick choice is kept too', (tester) async {
      await _pumpPage(tester, reference: _me);
      await tester.tap(find.widgetWithText(ChoiceChip, '100 km'));
      await tester.pumpAndSettle();

      ListingRadiusStore.instance.resetForTest();
      await tester.pumpWidget(const SizedBox());
      await _pumpPage(tester, reference: _me);

      expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '100 km')).selected, isTrue);
      expect(find.text('Gioco lontano'), findsOneWidget);
    });

    testWidgets('values outside 1-300 or not whole are refused', (tester) async {
      await _pumpPage(tester, reference: _me);

      await tester.tap(find.byKey(const ValueKey('marketplace-radius-other')));
      await tester.pumpAndSettle();
      for (final bad in ['0', '301', '']) {
        await tester.enterText(find.byKey(const ValueKey('marketplace-radius-field')), bad);
        await tester.tap(find.byKey(const ValueKey('marketplace-radius-confirm')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('marketplace-radius-field')), findsOneWidget, reason: bad);
        expect(find.textContaining('Valore non valido'), findsOneWidget, reason: bad);
      }
      expect((await SharedPreferences.getInstance()).getInt('vet_app.marketplace_radius_km'), isNull);

      await tester.enterText(find.byKey(const ValueKey('marketplace-radius-field')), '300');
      await tester.tap(find.byKey(const ValueKey('marketplace-radius-confirm')));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ChoiceChip, 'Altro: 300 km'), findsOneWidget);
    });
  });

  testWidgets('an ad from across the border shows with its seller flag, inside the radius',
      (tester) async {
    await _pumpPage(tester, reference: _me);

    expect(find.text('Pallina vicina'), findsOneWidget);
    expect(find.text('Annuncio francese'), findsOneWidget);
    // The French flag is in the row of the French ad only.
    expect(find.textContaining('\u{1F1EB}\u{1F1F7}'), findsOneWidget);
    expect(find.textContaining('\u{1F1EE}\u{1F1F9}'), findsNothing);
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
    await tester.pumpAndSettle();
    expect(find.text('Collare a 4 km'), findsOneWidget);
    expect(find.text('Gioco a 8 km'), findsNothing);

    // 1 km (via "Altro") leaves the collar at 4 km out.
    await tester.tap(find.byKey(const ValueKey('marketplace-radius-other')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('marketplace-radius-field')), '1');
    await tester.tap(find.byKey(const ValueKey('marketplace-radius-confirm')));
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

  testWidgets('without a position no ad is shown, the page asks for it and offers the way',
      (tester) async {
    await _pumpPage(tester);

    expect(find.text('Pallina vicina'), findsNothing);
    expect(find.text('Gioco lontano'), findsNothing);
    expect(find.textContaining('Imposta la tua posizione'), findsOneWidget);
    final chip = tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '10 km'));
    expect(chip.onSelected, isNull);

    // The button leads straight to Impostazioni → Località.
    HomeShellNavigation.consumeLocationScroll();
    await tester.tap(find.byKey(const ValueKey('marketplace-set-location')));
    expect(find.widgetWithText(FilledButton, 'Imposta la posizione'), findsOneWidget);
    expect(HomeShellNavigation.consumeLocationScroll(), isTrue);
  });

  testWidgets('with a position there is no set-location button', (tester) async {
    await _pumpPage(tester, reference: _me);
    expect(find.byKey(const ValueKey('marketplace-set-location')), findsNothing);
  });

  group('in the UK', () {
    setUp(() async => useLanguageVariant('en-GB'));
    tearDown(resetTerritoryForTest);

    testWidgets('radius is shown in miles but kept in km, 31 mi (50 km) preselected', (tester) async {
      await _pumpPage(tester, reference: _me);

      for (final label in ['6 mi', '16 mi', '31 mi', '62 mi']) {
        expect(find.widgetWithText(ChoiceChip, label), findsOneWidget, reason: label);
      }
      expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '31 mi')).selected, isTrue);
      expect(ListingRadiusStore.instance.radiusKm, 50);
      expect(find.textContaining('Anywhere'), findsNothing);
    });

    testWidgets('"Other" takes miles and stores whole kilometres', (tester) async {
      await _pumpPage(tester, reference: _me);

      await tester.tap(find.byKey(const ValueKey('marketplace-radius-other')));
      await tester.pumpAndSettle();
      expect(find.textContaining('1 to 186 mi'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('marketplace-radius-field')), '10');
      await tester.tap(find.byKey(const ValueKey('marketplace-radius-confirm')));
      await tester.pumpAndSettle();

      expect(ListingRadiusStore.instance.radiusKm, 16);
      expect((await SharedPreferences.getInstance()).getInt('vet_app.marketplace_radius_km'), 16);
      expect(find.widgetWithText(ChoiceChip, 'Other: 10 mi'), findsOneWidget);
    });
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
