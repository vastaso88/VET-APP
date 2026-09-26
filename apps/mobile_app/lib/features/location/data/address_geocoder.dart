import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/coordinates.dart';

class GeocodedAddress {
  const GeocodedAddress({required this.coordinates, required this.displayLabel});

  final Coordinates coordinates;
  final String displayLabel;
}

/// Injectable boundary around a geocoding provider, same pattern as
/// [LocationSampler] in device_location_service.dart — callers/tests
/// substitute a fake result instead of hitting the network.
abstract class AddressGeocoder {
  Future<GeocodedAddress?> geocode({
    required String street,
    required String postalCode,
    required String city,
    required String country,
  });
}

/// Free, keyless geocoding via OpenStreetMap's Nominatim — the same
/// "no API key/billing" choice already made for the maps themselves (see
/// docs/maps/01_localita_fondamenta_condivise.md, which picked flutter_map
/// + OSM tiles over google_maps_flutter for this exact reason). Returns
/// null on any network error or when no match is found; never throws.
class NominatimAddressGeocoder implements AddressGeocoder {
  NominatimAddressGeocoder({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _endpoint = 'https://nominatim.openstreetmap.org/search';

  @override
  Future<GeocodedAddress?> geocode({
    required String street,
    required String postalCode,
    required String city,
    required String country,
  }) async {
    final query =
        [street, postalCode, city, country].where((part) => part.trim().isNotEmpty).join(', ');
    if (query.isEmpty) {
      return null;
    }

    final uri = Uri.parse(_endpoint).replace(queryParameters: {
      'q': query,
      'format': 'json',
      'limit': '1',
    });

    try {
      // Nominatim's usage policy requires a descriptive User-Agent instead
      // of an API key — same identifier already used for the map tiles.
      final response = await _client
          .get(uri, headers: {'User-Agent': 'com.vetapp.mobile_app'})
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        return null;
      }

      final results = jsonDecode(response.body) as List<dynamic>;
      if (results.isEmpty) {
        return null;
      }

      final match = results.first as Map<String, dynamic>;
      final latitude = double.tryParse(match['lat'] as String? ?? '');
      final longitude = double.tryParse(match['lon'] as String? ?? '');
      if (latitude == null || longitude == null) {
        return null;
      }

      return GeocodedAddress(
        coordinates: Coordinates(latitude: latitude, longitude: longitude),
        displayLabel: (match['display_name'] as String?) ?? query,
      );
    } catch (_) {
      return null;
    }
  }
}
