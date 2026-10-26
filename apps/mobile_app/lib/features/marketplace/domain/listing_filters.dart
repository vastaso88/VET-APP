import '../../location/domain/coordinates.dart';
import '../../location/domain/geo_math.dart';
import '../../territory/domain/territory.dart';
import 'marketplace_listing.dart';

/// Preselected when the user has a position (owner decision, 2026-10-07):
/// 25 km, or 15 mi for owners who read miles. There is no "everywhere": a
/// search always has a radius and a centre (owner decision, 2026-10-14).
const defaultListingDistanceKm = 25.0;

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
/// Three rules, all of them hard:
/// * no [reference] position -> nothing: the Mercatino is local, so without
///   a centre there is no search to run;
/// * the radius is capped at [marketplaceMaxRadiusKm];
/// * only listings of [country] (default: the owner's) are kept, so an ad
///   from another country never shows, however close the border is.
/// Nearest first.
List<ListingMatch> applyListingFilter(
  List<MarketplaceListing> listings,
  ListingFilter filter, {
  required Coordinates? reference,
  String? country,
}) {
  if (reference == null) return const [];
  final countryCode = (country ?? currentTerritory().countryCode).toUpperCase();
  final limitMeters = clampMarketplaceRadiusKm(filter.maxDistanceKm) * 1000;

  final matches = <ListingMatch>[];
  for (final listing in listings) {
    if (listing.country.toUpperCase() != countryCode) continue;
    if (filter.category != null && listing.category != filter.category) continue;
    if (filter.species != null && !listing.isFor(filter.species!)) continue;
    final distance = haversineMeters(reference, listing.location);
    if (distance > limitMeters) continue;
    matches.add(ListingMatch(listing, distance));
  }

  matches.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
  return matches;
}
