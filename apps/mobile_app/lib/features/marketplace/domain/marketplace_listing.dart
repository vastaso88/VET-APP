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
    // Already fuzzed server-side before this ever reaches the client -
    // see packages/core/application/services/create_listing.py.
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
}
