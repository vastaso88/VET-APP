import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../shared/auth/current_user.dart';
import '../../../shared/config/app_runtime_config_loader.dart';
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

/// Address search through VetApp's backend (POST /geocoding/search), which
/// asks OpenStreetMap's Nominatim on the app's behalf. The phone never
/// talks to Nominatim itself: the user's home address and IP address do
/// not reach a third party (security audit APP-6). The backend applies
/// Nominatim's usage policy (identifying User-Agent, one request per
/// second, cache) and a per-account limit. The address travels in the
/// request body, not in the URL, so it does not end up in access logs.
///
/// For a supported country the address is written in that country's order
/// and the search is limited to it, so "Via Roma" typed for Italy is never
/// resolved to a street of the same name elsewhere. Returns null without a
/// backend or a session, on any error, or when nothing matches; never throws.
///
/// The name is kept from when the app called Nominatim directly.
class NominatimAddressGeocoder implements AddressGeocoder {
  NominatimAddressGeocoder({
    http.Client? client,
    AppRuntimeConfigLoader? configLoader,
    String? Function()? accessToken,
  })  : _client = client ?? http.Client(),
        _configLoader = configLoader ?? const AppRuntimeConfigLoader(),
        _accessToken = accessToken ?? CurrentUser.accessToken;

  final http.Client _client;
  final AppRuntimeConfigLoader _configLoader;
  final String? Function() _accessToken;

  @override
  Future<GeocodedAddress?> geocode({
    required String street,
    required String postalCode,
    required String city,
    required String country,
  }) async {
    final supported = supportedCountryForName(country);
    final query = [
      formatAddress(
          AddressParts(street: street, postcode: postalCode, city: city), supported?.code),
      country,
    ].where((part) => part.trim().isNotEmpty).join(', ');
    if (query.isEmpty) {
      return null;
    }
    final json = await postToGeocodingBackend(
      _client,
      _configLoader,
      _accessToken,
      '/geocoding/search',
      {
        'query': query,
        if (supported != null) 'country_code': supported.nominatimCode,
      },
    );
    final results = json?['results'];
    if (results is! List || results.isEmpty || results.first is! Map<String, dynamic>) {
      return null;
    }
    final match = results.first as Map<String, dynamic>;
    final latitude = (match['latitude'] as num?)?.toDouble();
    final longitude = (match['longitude'] as num?)?.toDouble();
    if (latitude == null || longitude == null) {
      return null;
    }
    final displayName = match['display_name'] as String?;
    return GeocodedAddress(
      coordinates: Coordinates(latitude: latitude, longitude: longitude),
      displayLabel: compactAddressLabel(
        match['address'] as Map<String, dynamic>?,
        displayName == null || displayName.isEmpty ? query : displayName,
      ),
    );
  }
}

/// One authenticated call to the backend's geocoding routes. Null without a
/// backend address or a session, on a non-2xx answer or on any error: the
/// callers treat geocoding as best-effort.
Future<Map<String, dynamic>?> postToGeocodingBackend(
  http.Client client,
  AppRuntimeConfigLoader configLoader,
  String? Function() accessToken,
  String path,
  Map<String, Object?> body,
) async {
  final baseUrl = configLoader.load().apiBaseUrl;
  final token = accessToken();
  if (baseUrl.isEmpty || token == null || token.isEmpty) {
    return null;
  }
  try {
    final response = await client
        .post(
          Uri.parse('$baseUrl$path'),
          headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    return decoded is Map<String, dynamic> ? decoded : null;
  } catch (_) {
    return null;
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
