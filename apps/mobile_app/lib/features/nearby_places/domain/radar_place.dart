import '../../location/domain/coordinates.dart';
import 'radar_community.dart';

/// Mirrors packages/core/domain/radar_places `place_type` values. Unknown
/// values coming from a newer backend fall back to [other] instead of
/// dropping the place.
enum RadarPlaceType {
  veterinary,
  grooming,
  shop,
  school,
  petSitting,
  breeder,
  hotel,
  dogPark,
  shelter,
  other,
}

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
    case 'dog_park':
      return RadarPlaceType.dogPark;
    case 'shelter':
      return RadarPlaceType.shelter;
    default:
      return RadarPlaceType.other;
  }
}

String radarPlaceTypeToApi(RadarPlaceType type) {
  switch (type) {
    case RadarPlaceType.veterinary:
      return 'veterinary';
    case RadarPlaceType.grooming:
      return 'grooming';
    case RadarPlaceType.shop:
      return 'shop';
    case RadarPlaceType.school:
      return 'school';
    case RadarPlaceType.petSitting:
      return 'pet_sitting';
    case RadarPlaceType.breeder:
      return 'breeder';
    case RadarPlaceType.hotel:
      return 'hotel';
    case RadarPlaceType.dogPark:
      return 'dog_park';
    case RadarPlaceType.shelter:
      return 'shelter';
    case RadarPlaceType.other:
      return 'other';
  }
}

/// A pet-related place near the user, as served by the backend's
/// `/local-services/places`. Every field comes from one open data source
/// ([sourceName]); other sources listing the same place are only named in
/// [confirmedBy], their data is not mixed in.
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
    this.openingHours,
    this.species = const [],
    this.details = const {},
    this.sourceName = 'openstreetmap_overpass',
    this.confirmedBy = const [],
    this.sourceExternalId = '',
    this.community,
    this.pendingClosure,
    this.rating,
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

  /// Raw OpenStreetMap `opening_hours` value. Shown as stated, never
  /// interpreted as "open now": the data is unverified.
  final String? openingHours;

  /// Canonical species keys (dog, cat, ...) the place is specifically for.
  /// Empty means "not stated", i.e. relevant to every species.
  final List<String> species;

  /// Facts the source states about the place (OpenStreetMap tags such as
  /// `barrier`, `lit`, `surface`). A missing key means "unknown".
  final Map<String, String> details;

  /// Backend name of the source this record comes from.
  final String sourceName;

  /// Other sources that list the same place.
  final List<String> confirmedBy;

  /// The source's own id of this place: what reports and ratings refer to.
  final String sourceExternalId;

  /// Set when the place itself is a user report ("missing place"), with
  /// its confirmation state.
  final RadarReportInfo? community;

  /// Set when users reported this place as closed and that is not yet
  /// confirmed (only when the backend is configured to show it).
  final RadarReportInfo? pendingClosure;

  /// Set for public dog parks, the only places that can be rated.
  final RadarRating? rating;

  /// A user report still waiting for other users to confirm it.
  bool get isPendingReport => community?.isPending ?? false;

  bool matchesSpecies(Set<String> wanted) =>
      wanted.isEmpty || species.isEmpty || species.any(wanted.contains);

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
    final details = json['details'];
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
      openingHours: _text(json['opening_hours']),
      species: _strings(json['species']),
      details: details is Map
          ? {
              for (final entry in details.entries)
                if (entry.value is String) entry.key.toString(): entry.value as String,
            }
          : const {},
      sourceName: _text(json['source_name']) ?? 'openstreetmap_overpass',
      confirmedBy: _strings(json['confirmed_by']),
      sourceExternalId: _text(json['source_external_id']) ?? '',
      community: RadarReportInfo.tryFromJson(json['community']),
      pendingClosure: RadarReportInfo.tryFromJson(json['pending_closure']),
      rating: RadarRating.tryFromJson(json['rating']),
    );
  }

  static List<String> _strings(Object? value) =>
      (value as List<dynamic>? ?? const []).whereType<String>().toList(growable: false);

  static String? _text(Object? value) {
    final text = value is String ? value.trim() : '';
    return text.isEmpty ? null : text;
  }
}
