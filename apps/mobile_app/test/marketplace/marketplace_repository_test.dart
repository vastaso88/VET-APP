import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/location/domain/coordinates.dart';
import 'package:vet_app_mobile/features/marketplace/data/marketplace_repository.dart';
import 'package:vet_app_mobile/features/marketplace/domain/marketplace_listing.dart';

void main() {
  test('without Supabase configured, saved listings come back from the local fallback', () async {
    final repository = MarketplaceRepository();
    final now = DateTime.now();
    final listing = MarketplaceListing(
      id: 'listing-test-${now.microsecondsSinceEpoch}',
      ownerId: 'user-1',
      title: 'Trasportino',
      category: ListingCategory.transportCarriers,
      condition: ListingCondition.good,
      location: const Coordinates(latitude: 45.4642, longitude: 9.1900),
      createdAt: now,
      updatedAt: now,
    );

    await repository.saveListing(listing);
    final active = await repository.loadActiveListings();

    expect(active.any((item) => item.id == listing.id), isTrue);
  });

  test('removed listings are excluded from the active list', () async {
    final repository = MarketplaceRepository();
    final now = DateTime.now();
    final removed = MarketplaceListing(
      id: 'listing-removed-${now.microsecondsSinceEpoch}',
      ownerId: 'user-1',
      title: 'Cuccia',
      category: ListingCategory.accessories,
      condition: ListingCondition.worn,
      location: const Coordinates(latitude: 45.4642, longitude: 9.1900),
      status: ListingStatus.removed,
      createdAt: now,
      updatedAt: now,
    );

    await repository.saveListing(removed);
    final active = await repository.loadActiveListings();

    expect(active.any((item) => item.id == removed.id), isFalse);
  });
}
