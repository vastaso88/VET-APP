import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/address_format.dart';
import '../domain/coordinates.dart';
import '../domain/supported_countries.dart';

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
///
/// Usage policy (https://operations.osmfoundation.org/policies/nominatim/):
/// at most one request per second, a User-Agent that identifies the app, no
/// autocomplete-as-you-type, results may be cached. A search runs only when
/// the person submits an address, so a single device stays far below that.
/// For a supported country the address is written in that country's order
/// and the search is limited to it (`countrycodes`), so "Via Roma" typed
/// for Italy is never resolved to a street of the same name elsewhere.
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
    final supported = supportedCountryForName(country);
    final query = [
      formatAddress(AddressParts(street: street, postcode: postalCode, city: city), supported?.code),
      country,
    ].where((part) => part.trim().isNotEmpty).join(', ');
    if (query.isEmpty) {
      return null;
    }

    final uri = Uri.parse(_endpoint).replace(queryParameters: {
      'q': query,
      'format': 'json',
      'limit': '1',
      'addressdetails': '1',
      if (supported != null) 'countrycodes': supported.nominatimCode,
    });

    try {
      // Nominatim's usage policy requires a descriptive User-Agent instead
      // of an API key — same identifier already used for the map tiles.
      final response = await _client.get(uri,
          headers: {'User-Agent': 'com.vetapp.mobile_app'}).timeout(const Duration(seconds: 10));
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
        displayLabel: compactAddressLabel(
          match['address'] as Map<String, dynamic>?,
          (match['display_name'] as String?) ?? query,
        ),
      );
    } catch (_) {
      return null;
    }
  }
}

/// True for a residence label saved before [compactAddressLabel] existed, i.e.
/// Nominatim's raw display_name: 3+ commas, or longer than 60 characters.
/// A compact label ("Via Roma 12, Torino") has one comma and is short.
bool isLegacyLongAddressLabel(String label) =>
    ','.allMatches(label).length >= 3 || label.length > 60;

/// "Piazza del Duomo 1, Milano" from Nominatim's structured address, written
/// in the order of the address's own country (see [formatAddress]), with the
/// postcode when Nominatim gave one. Falls back to the full display name when
/// the street or city is missing.
String compactAddressLabel(Map<String, dynamic>? address, String fallback) {
  if (address == null) return fallback;
  final parts = AddressParts.fromNominatim(address);
  if (parts.street == null || parts.city == null) return fallback;
  return formatAddress(parts, address['country_code'] as String?);
}
