import '../../location/domain/coordinates.dart';

/// Owner-facing list agreed 2026-10-07 (session "Mercatino"). The wire
/// values of the categories this replaced (food, accessories,
/// health_wellness, transport_carriers, grooming) are still read - see
/// MarketplaceRepository's legacy mapping - so rows written before the
/// change keep showing up.
enum ListingCategory {
  kennelsCarriers,
  leashesCollars,
  toys,
  clothing,
  feeding,
  hygieneGrooming,
  aquariumsTerrariums,
  cagesAviaries,
  other,
}

enum ListingCondition { newItem, likeNew, good, worn }

enum ListingStatus { active, reserved, sold, removed }

/// Same groups as the pet species picker (pets/data/pet_demo_store.dart),
/// plus [allSpecies] for generic items (a bowl, a carrier for "any" pet).
/// Every listing has at least one; [allSpecies] is never combined with the
/// others (create_listing_page.dart enforces both).
enum ListingSpecies { allSpecies, dog, cat, smallMammal, bird, reptileAmphibian, fish, other }

class MarketplaceListing {
  const MarketplaceListing({
    required this.id,
    required this.ownerId,
    required this.title,
    this.description,
    required this.category,
    required this.condition,
    this.priceCents,
    this.photoUrls = const [],
    this.species = const [],
    // Must already be approximated by the caller before construction - see
    // marketplace/domain/listing_location.dart:approximateListingLocation.
    // The app writes straight to Supabase (no backend API in between), so
    // this is a caller contract, not something this class enforces itself.
    required this.location,
    this.cityLabel,
    this.status = ListingStatus.active,
    this.reportCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String ownerId;
  final String title;
  final String? description;
  final ListingCategory category;
  final ListingCondition condition;

  /// Null means "in regalo".
  final int? priceCents;
  final List<String> photoUrls;
  final List<ListingSpecies> species;
  final Coordinates location;

  /// Neighbourhood/town only ("Navigli, Milano"), never a street address.
  final String? cityLabel;
  final ListingStatus status;
  final int reportCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isGift => priceCents == null;

  /// True when the item suits [species]. Listings for all species, and rows
  /// saved before species existed (empty list), suit everyone.
  bool isFor(ListingSpecies species) =>
      this.species.isEmpty ||
      this.species.contains(ListingSpecies.allSpecies) ||
      this.species.contains(species);

  MarketplaceListing copyWith({
    String? title,
    String? Function()? description,
    ListingCategory? category,
    ListingCondition? condition,
    int? Function()? priceCents,
    List<String>? photoUrls,
    List<ListingSpecies>? species,
    Coordinates? location,
    String? Function()? cityLabel,
    ListingStatus? status,
    int? reportCount,
    DateTime? updatedAt,
  }) {
    return MarketplaceListing(
      id: id,
      ownerId: ownerId,
      title: title ?? this.title,
      description: description != null ? description() : this.description,
      category: category ?? this.category,
      condition: condition ?? this.condition,
      priceCents: priceCents != null ? priceCents() : this.priceCents,
      photoUrls: photoUrls ?? this.photoUrls,
      species: species ?? this.species,
      location: location ?? this.location,
      cityLabel: cityLabel != null ? cityLabel() : this.cityLabel,
      status: status ?? this.status,
      reportCount: reportCount ?? this.reportCount,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
