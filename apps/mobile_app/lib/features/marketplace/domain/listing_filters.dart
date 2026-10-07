import '../../location/domain/coordinates.dart';
import '../../location/domain/geo_math.dart';
import 'marketplace_listing.dart';

/// Distance choices offered in the filter row; null is "Ovunque".
const listingDistanceOptionsKm = <double?>[2, 5, 10, 25, null];

/// Preselected when the user has a position (owner decision, 2026-10-07).
const defaultListingDistanceKm = 25.0;

class ListingFilter {
  const ListingFilter({this.category, this.species, this.maxDistanceKm});

  final ListingCategory? category;

  /// One concrete species (never [ListingSpecies.allSpecies]); null is any.
  final ListingSpecies? species;
  final double? maxDistanceKm;

  ListingFilter withCategory(ListingCategory? category) =>
      ListingFilter(category: category, species: species, maxDistanceKm: maxDistanceKm);

  ListingFilter withSpecies(ListingSpecies? species) =>
      ListingFilter(category: category, species: species, maxDistanceKm: maxDistanceKm);

  ListingFilter withMaxDistance(double? maxDistanceKm) =>
      ListingFilter(category: category, species: species, maxDistanceKm: maxDistanceKm);
}

class ListingMatch {
  const ListingMatch(this.listing, this.distanceMeters);

  final MarketplaceListing listing;

  /// Null when the user has no position to measure from.
  final double? distanceMeters;
}

/// The one filter both the list and the map read, so they can never show
/// different sets. Without a [reference] the distance limit can't apply:
/// everything is kept, newest first. With one, nearest first.
List<ListingMatch> applyListingFilter(
  List<MarketplaceListing> listings,
  ListingFilter filter, {
  Coordinates? reference,
}) {
  final matches = <ListingMatch>[];
  for (final listing in listings) {
    if (filter.category != null && listing.category != filter.category) continue;
    if (filter.species != null && !listing.isFor(filter.species!)) continue;
    final distance = reference == null ? null : haversineMeters(reference, listing.location);
    final limitKm = filter.maxDistanceKm;
    if (distance != null && limitKm != null && distance > limitKm * 1000) continue;
    matches.add(ListingMatch(listing, distance));
  }

  if (reference == null) {
    matches.sort((a, b) => b.listing.createdAt.compareTo(a.listing.createdAt));
  } else {
    matches.sort((a, b) => a.distanceMeters!.compareTo(b.distanceMeters!));
  }
  return matches;
}
