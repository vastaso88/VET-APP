import '../../location/domain/coordinates.dart';

enum ListingCategory {
  food,
  accessories,
  healthWellness,
  transportCarriers,
  toys,
  grooming,
  other,
}

enum ListingCondition { newItem, likeNew, good, worn }

enum ListingStatus { active, reserved, sold, removed }

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
    // Must already be fuzzed by the caller before construction - see
    // location/domain/geo_math.dart:fuzzCoordinates. The app writes
    // straight to Supabase (no backend API in between), so this is a
    // caller contract, not something this class enforces itself.
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
  final int? priceCents;
  final List<String> photoUrls;
  final Coordinates location;
  final String? cityLabel;
  final ListingStatus status;
  final int reportCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  MarketplaceListing copyWith({
    ListingStatus? status,
    int? reportCount,
    DateTime? updatedAt,
  }) {
    return MarketplaceListing(
      id: id,
      ownerId: ownerId,
      title: title,
      description: description,
      category: category,
      condition: condition,
      priceCents: priceCents,
      photoUrls: photoUrls,
      location: location,
      cityLabel: cityLabel,
      status: status ?? this.status,
      reportCount: reportCount ?? this.reportCount,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
