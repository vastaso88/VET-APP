import '../../location/domain/coordinates.dart';
import '../../location/domain/geo_math.dart';
import '../../territory/domain/territory.dart';
import 'marketplace_listing.dart';

/// Preselected when the user has a position (owner decision, 2026-10-26):
/// 50 km, whatever the unit shown. There is no "everywhere": a search always
/// has a radius and a centre (owner decision, 2026-10-14).
const defaultListingDistanceKm = defaultMarketplaceRadiusKmValue;

class ListingFilter {
  const ListingFilter({
    this.category,
    this.species,
    this.maxDistanceKm = defaultListingDistanceKm,
  });

  final ListingCategory? category;

  /// One concrete species (never [ListingSpecies.allSpecies]); null is any.
  final ListingSpecies? species;

  /// Search radius in kilometres, at most [marketplaceMaxRadiusKm].
  final double maxDistanceKm;

  ListingFilter withCategory(ListingCategory? category) =>
      ListingFilter(category: category, species: species, maxDistanceKm: maxDistanceKm);

  ListingFilter withSpecies(ListingSpecies? species) =>
      ListingFilter(category: category, species: species, maxDistanceKm: maxDistanceKm);

  ListingFilter withMaxDistance(double maxDistanceKm) =>
      ListingFilter(category: category, species: species, maxDistanceKm: maxDistanceKm);
}

class ListingMatch {
  const ListingMatch(this.listing, this.distanceMeters);

  final MarketplaceListing listing;
  final double distanceMeters;
}

/// The one filter both the list and the map read, so they can never show
/// different sets.
///
/// Two rules, both hard:
/// * no [reference] position -> nothing: the Mercatino is local, so without
///   a centre there is no search to run;
/// * the radius is kept between [marketplaceMinRadiusKm] and
///   [marketplaceMaxRadiusKm].
/// Distance is the filter on where an ad is: near a border the ads across it
/// count too (they show the seller's flag and currency). Nearest first.
List<ListingMatch> applyListingFilter(
  List<MarketplaceListing> listings,
  ListingFilter filter, {
  required Coordinates? reference,
}) {
  if (reference == null) return const [];
  final limitMeters = clampMarketplaceRadiusKm(filter.maxDistanceKm) * 1000;

  final matches = <ListingMatch>[];
  for (final listing in listings) {
    if (filter.category != null && listing.category != filter.category) continue;
    if (filter.species != null && !listing.isFor(filter.species!)) continue;
    final distance = haversineMeters(reference, listing.location);
    if (distance > limitMeters) continue;
    matches.add(ListingMatch(listing, distance));
  }

  matches.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
  return matches;
}
