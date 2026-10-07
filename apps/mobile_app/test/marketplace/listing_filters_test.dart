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
}) {
  final created = DateTime(2026, 10, 7).subtract(Duration(days: ageDays));
  return MarketplaceListing(
    id: id,
    ownerId: 'seller',
    title: id,
    category: category,
    condition: ListingCondition.good,
    species: species,
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
    expect(ids(applyListingFilter(listings, const ListingFilter(), reference: _me)),
        ['toy-1km', 'leash-4km', 'toy-8km', 'cage-20km', 'toy-60km']);
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

  test('without a reference the distance limit is ignored and newest come first', () {
    final matches = applyListingFilter(listings, const ListingFilter(maxDistanceKm: 2));
    expect(ids(matches), ['toy-8km', 'leash-4km', 'toy-60km', 'toy-1km', 'cage-20km']);
    expect(matches.every((m) => m.distanceMeters == null), isTrue);
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
