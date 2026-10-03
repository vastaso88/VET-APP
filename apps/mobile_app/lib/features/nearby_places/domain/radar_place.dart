import '../../location/domain/coordinates.dart';

/// Mirrors packages/core/domain/radar_places `place_type` values. Unknown
/// values coming from a newer backend fall back to [other] instead of
/// dropping the place.
enum RadarPlaceType { veterinary, grooming, shop, school, petSitting, breeder, hotel, other }

RadarPlaceType radarPlaceTypeFromApi(String? value) {
  switch (value) {
    case 'veterinary':
      return RadarPlaceType.veterinary;
    case 'grooming':
      return RadarPlaceType.grooming;
    case 'shop':
      return RadarPlaceType.shop;
    case 'school':
      return RadarPlaceType.school;
    case 'pet_sitting':
      return RadarPlaceType.petSitting;
    case 'breeder':
      return RadarPlaceType.breeder;
    case 'hotel':
      return RadarPlaceType.hotel;
    default:
      return RadarPlaceType.other;
  }
}

/// A pet-related business near the user, as served by the backend's
/// `/local-services/places` (OpenStreetMap data, cached per area).
class RadarPlace {
  const RadarPlace({
    required this.id,
    required this.type,
    required this.name,
    required this.location,
    required this.distanceMeters,
    this.addressLabel,
    this.city,
    this.phone,
    this.websiteUrl,
    this.sourceUrl,
    this.summary,
  });

  final String id;
  final RadarPlaceType type;
  final String name;
  final Coordinates location;
  final double distanceMeters;
  final String? addressLabel;
  final String? city;
  final String? phone;
  final String? websiteUrl;
  final String? sourceUrl;
  final String? summary;

  /// Returns null for rows without a usable name/position rather than
  /// throwing: one malformed place must not hide the whole list.
  static RadarPlace? tryFromJson(Map<String, dynamic> json) {
    final name = (json['name'] as String?)?.trim() ?? '';
    final latitude = (json['latitude'] as num?)?.toDouble();
    final longitude = (json['longitude'] as num?)?.toDouble();
    if (name.isEmpty || latitude == null || longitude == null) {
      return null;
    }
    final websiteUrl = _text(json['website_url']);
    final sourceUrl = _text(json['source_url']);
    return RadarPlace(
      id: (json['id'] as String?) ?? '$name@$latitude,$longitude',
      type: radarPlaceTypeFromApi(json['place_type'] as String?),
      name: name,
      location: Coordinates(latitude: latitude, longitude: longitude),
      distanceMeters: ((json['distance_km'] as num?)?.toDouble() ?? 0) * 1000,
      addressLabel: _text(json['address_label']),
      city: _text(json['city']),
      phone: _text(json['phone']),
      // The backend falls back to the OpenStreetMap page when a place has
      // no website; that is attribution, not the business's own site.
      websiteUrl: websiteUrl == sourceUrl ? null : websiteUrl,
      sourceUrl: sourceUrl,
      summary: _text(json['summary']),
    );
  }

  static String? _text(Object? value) {
    final text = value is String ? value.trim() : '';
    return text.isEmpty ? null : text;
  }
}
