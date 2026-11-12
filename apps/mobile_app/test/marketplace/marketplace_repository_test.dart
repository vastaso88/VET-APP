import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/location/domain/coordinates.dart';
import 'package:vet_app_mobile/features/marketplace/data/marketplace_repository.dart';
import 'package:vet_app_mobile/features/marketplace/domain/marketplace_listing.dart';

MarketplaceListing _listing(
  String id, {
  String ownerId = 'seller-1',
  ListingStatus status = ListingStatus.active,
}) {
  final now = DateTime(2026, 10, 7);
  return MarketplaceListing(
    id: id,
    ownerId: ownerId,
    title: 'Trasportino $id',
    category: ListingCategory.kennelsCarriers,
    condition: ListingCondition.good,
    priceCents: 2000,
    location: const Coordinates(latitude: 45.46, longitude: 9.19),
    status: status,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  test('without Supabase configured, created listings come back from the local store', () async {
    final repository = MarketplaceRepository.inMemory(const []);
    final listing = _listing('a');

    await repository.createListing(listing);
    final active = await repository.loadActiveListings();

    expect(active.map((item) => item.id), ['a']);
  });

  test('removed listings are excluded from the active list', () async {
    final repository = MarketplaceRepository.inMemory([
      _listing('active'),
      _listing('removed', status: ListingStatus.removed),
    ]);

    final active = await repository.loadActiveListings();

    expect(active.map((item) => item.id), ['active']);
  });

  test('the demo seed shows up only in the shared store used without a backend', () async {
    final active = await MarketplaceRepository.inMemory(const []).loadActiveListings();
    expect(active, isEmpty);

    final shared = await MarketplaceRepository().loadActiveListings();
    expect(shared.any((item) => item.id == 'demo-listing-cuccia'), isTrue);
  });

  group('edit and delete permissions', () {
    test('canManageListing is true only for the author', () {
      final listing = _listing('a', ownerId: 'seller-1');
      expect(canManageListing(listing, 'seller-1'), isTrue);
      expect(canManageListing(listing, 'someone-else'), isFalse);
      expect(canManageListing(listing, ''), isFalse);
    });

    test('the author can update their listing', () async {
      final repository = MarketplaceRepository.inMemory([_listing('a')]);

      await repository.updateListing(
        _listing('a').copyWith(title: 'Nuovo titolo', priceCents: () => null),
        requesterId: 'seller-1',
      );

      final stored = (await repository.loadActiveListings()).single;
      expect(stored.title, 'Nuovo titolo');
      expect(stored.isGift, isTrue);
    });

    test('someone else cannot update the listing', () async {
      final repository = MarketplaceRepository.inMemory([_listing('a')]);

      await expectLater(
        repository.updateListing(_listing('a').copyWith(title: 'Rubato'), requesterId: 'intruder'),
        throwsA(isA<ListingPermissionException>()),
      );
      expect((await repository.loadActiveListings()).single.title, 'Trasportino a');
    });

    test('ownership is read from the stored listing, not from the copy passed in', () async {
      final repository = MarketplaceRepository.inMemory([_listing('a', ownerId: 'seller-1')]);
      final forged = _listing('a', ownerId: 'intruder').copyWith(title: 'Rubato');

      await expectLater(
        repository.updateListing(forged, requesterId: 'intruder'),
        throwsA(isA<ListingPermissionException>()),
      );
      await expectLater(
        repository.deleteListing(forged, requesterId: 'intruder'),
        throwsA(isA<ListingPermissionException>()),
      );
      expect(await repository.loadActiveListings(), hasLength(1));
    });

    test('the author can delete their listing', () async {
      final repository = MarketplaceRepository.inMemory([_listing('a'), _listing('b')]);

      await repository.deleteListing(_listing('a'), requesterId: 'seller-1');

      expect((await repository.loadActiveListings()).map((item) => item.id), ['b']);
    });

    test('someone else cannot delete the listing', () async {
      final repository = MarketplaceRepository.inMemory([_listing('a')]);

      await expectLater(
        repository.deleteListing(_listing('a'), requesterId: 'intruder'),
        throwsA(isA<ListingPermissionException>()),
      );
      expect(await repository.loadActiveListings(), hasLength(1));
    });

    test('updating or deleting a listing that does not exist is refused', () async {
      final repository = MarketplaceRepository.inMemory(const []);

      await expectLater(
        repository.updateListing(_listing('ghost'), requesterId: 'seller-1'),
        throwsA(isA<ListingPermissionException>()),
      );
      await expectLater(
        repository.deleteListing(_listing('ghost'), requesterId: 'seller-1'),
        throwsA(isA<ListingPermissionException>()),
      );
    });
  });

  group('wire values', () {
    test('every category round-trips', () {
      for (final category in ListingCategory.values) {
        expect(categoryFromWire(categoryToWire(category)), category);
      }
    });

    test('categories used before the new list map to the closest current one', () {
      expect(categoryFromWire('transport_carriers'), ListingCategory.kennelsCarriers);
      expect(categoryFromWire('food'), ListingCategory.feeding);
      expect(categoryFromWire('grooming'), ListingCategory.hygieneGrooming);
      expect(categoryFromWire('accessories'), ListingCategory.other);
      expect(categoryFromWire('health_wellness'), ListingCategory.other);
      expect(categoryFromWire('unknown'), isNull);
    });

    test('every species round-trips', () {
      for (final species in ListingSpecies.values) {
        expect(speciesFromWire(speciesToWire(species)), species);
      }
    });
  });
}
