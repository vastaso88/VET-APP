import 'package:flutter_test/flutter_test.dart';
import 'package:vet_app_mobile/features/location/domain/coordinates.dart';
import 'package:vet_app_mobile/features/marketplace/domain/listing_filters.dart';
import 'package:vet_app_mobile/features/marketplace/domain/marketplace_listing.dart';
import 'package:vet_app_mobile/features/marketplace/presentation/pages/marketplace_map_page.dart';

const _me = Coordinates(latitude: 45.46, longitude: 9.19);

/// ~1.1 km per 0.01° of latitude, so `kmNorth` places a listing that far
/// north of [_me].
MarketplaceListing _listing(
  String id,
  ListingCategory category, {
  required double kmNorth,
  int ageDays = 0,
  List<ListingSpecies> species = const [ListingSpecies.dog],
  String country = 'IT',
}) {
  final created = DateTime(2026, 10, 7).subtract(Duration(days: ageDays));
  return MarketplaceListing(
    id: id,
    ownerId: 'seller',
    title: id,
    category: category,
    condition: ListingCondition.good,
    species: species,
    country: country,
    location: Coordinates(latitude: _me.latitude + kmNorth / 111.2, longitude: _me.longitude),
    createdAt: created,
    updatedAt: created,
  );
}

void main() {
  final listings = [
    _listing('toy-1km', ListingCategory.toys, kmNorth: 1, ageDays: 3),
    _listing('leash-4km', ListingCategory.leashesCollars, kmNorth: 4, ageDays: 1),
    _listing('toy-8km', ListingCategory.toys, kmNorth: 8, ageDays: 0),
    _listing('cage-20km', ListingCategory.cagesAviaries, kmNorth: 20, ageDays: 5),
    _listing('toy-60km', ListingCategory.toys, kmNorth: 60, ageDays: 2),
  ];

  List<String> ids(List<ListingMatch> matches) => matches.map((m) => m.listing.id).toList();

  test('distance limits keep only listings inside the radius, nearest first', () {
    expect(ids(applyListingFilter(listings, const ListingFilter(maxDistanceKm: 2), reference: _me)),
        ['toy-1km']);
    expect(ids(applyListingFilter(listings, const ListingFilter(maxDistanceKm: 5), reference: _me)),
        ['toy-1km', 'leash-4km']);
    expect(
        ids(applyListingFilter(listings, const ListingFilter(maxDistanceKm: 10), reference: _me)),
        ['toy-1km', 'leash-4km', 'toy-8km']);
    expect(
        ids(applyListingFilter(listings, const ListingFilter(maxDistanceKm: 25), reference: _me)),
        ['toy-1km', 'leash-4km', 'toy-8km', 'cage-20km']);
    // Default radius: 25 km.
    expect(ids(applyListingFilter(listings, const ListingFilter(), reference: _me)),
        ['toy-1km', 'leash-4km', 'toy-8km', 'cage-20km']);
  });

  test('the radius never goes past 50 km, whatever the filter asks', () {
    final far = [
      ...listings,
      _listing('toy-45km', ListingCategory.toys, kmNorth: 45),
    ];
    final wide = applyListingFilter(far, const ListingFilter(maxDistanceKm: 50), reference: _me);
    expect(ids(wide), contains('toy-45km'));
    expect(ids(wide), isNot(contains('toy-60km')));

    final absurd = applyListingFilter(far, const ListingFilter(maxDistanceKm: 5000), reference: _me);
    expect(ids(absurd), isNot(contains('toy-60km')), reason: 'clamped to the 50 km maximum');
  });

  test('without a position there is no search at all - nothing is returned', () {
    expect(applyListingFilter(listings, const ListingFilter(maxDistanceKm: 50), reference: null),
        isEmpty);
    expect(applyListingFilter(listings, const ListingFilter(), reference: null), isEmpty);
  });

  test('only the country of the owner is shown, however close the ad is', () {
    final mixed = [
      _listing('it-near', ListingCategory.toys, kmNorth: 1),
      _listing('fr-near', ListingCategory.toys, kmNorth: 1, country: 'FR'),
      _listing('ch-near', ListingCategory.toys, kmNorth: 2, country: 'CH'),
    ];
    expect(ids(applyListingFilter(mixed, const ListingFilter(), reference: _me, country: 'IT')),
        ['it-near']);
    expect(ids(applyListingFilter(mixed, const ListingFilter(), reference: _me, country: 'FR')),
        ['fr-near']);
    expect(ids(applyListingFilter(mixed, const ListingFilter(), reference: _me, country: 'ch')),
        ['ch-near']);
    expect(applyListingFilter(mixed, const ListingFilter(), reference: _me, country: 'DE'), isEmpty);
  });

  test('a listing written before the country column counts as Italian', () {
    final legacy = _listing('old-row', ListingCategory.toys, kmNorth: 1);
    expect(legacy.country, 'IT');
  });

  test('category and distance combine', () {
    final matches = applyListingFilter(
      listings,
      const ListingFilter(category: ListingCategory.toys, maxDistanceKm: 10),
      reference: _me,
    );
    expect(ids(matches), ['toy-1km', 'toy-8km']);
  });

  test('distances are reported in meters', () {
    final match = applyListingFilter(
      listings,
      const ListingFilter(maxDistanceKm: 2),
      reference: _me,
    ).single;
    expect(match.distanceMeters, closeTo(1000, 5));
  });

  test('listings in the same grid cell share one map marker', () {
    final sameCell = [
      _listing('a', ListingCategory.toys, kmNorth: 0),
      _listing('b', ListingCategory.toys, kmNorth: 0),
      _listing('c', ListingCategory.toys, kmNorth: 5),
    ];
    final clusters = clusterListingsByLocation(
      applyListingFilter(sameCell, const ListingFilter(), reference: _me),
    );
    expect(clusters.map((c) => c.matches.length).toList()..sort(), [1, 2]);
  });

  test('the species filter keeps that species and the items for all species', () {
    final mixed = [
      _listing('dog', ListingCategory.toys, kmNorth: 1),
      _listing('cat', ListingCategory.toys, kmNorth: 2, species: const [ListingSpecies.cat]),
      _listing(
        'dog-and-cat',
        ListingCategory.toys,
        kmNorth: 3,
        species: const [ListingSpecies.dog, ListingSpecies.cat],
      ),
      _listing('any', ListingCategory.feeding,
          kmNorth: 4, species: const [ListingSpecies.allSpecies]),
      _listing('old-row', ListingCategory.feeding, kmNorth: 5, species: const []),
    ];

    expect(
      ids(applyListingFilter(mixed, const ListingFilter(species: ListingSpecies.cat),
          reference: _me)),
      ['cat', 'dog-and-cat', 'any', 'old-row'],
    );
    expect(
      ids(applyListingFilter(mixed, const ListingFilter(species: ListingSpecies.fish),
          reference: _me)),
      ['any', 'old-row'],
    );
    expect(
      ids(
        applyListingFilter(
          mixed,
          const ListingFilter(category: ListingCategory.toys, species: ListingSpecies.dog),
          reference: _me,
        ),
      ),
      ['dog', 'dog-and-cat'],
    );
  });
}
