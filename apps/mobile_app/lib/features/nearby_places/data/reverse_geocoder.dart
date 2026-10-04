import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../location/domain/coordinates.dart';

/// Street address of a point, via OpenStreetMap's Nominatim (the same
/// keyless provider the Località settings use to geocode an address). One
/// request per report, well inside Nominatim's usage policy. Best-effort:
/// null on any failure, and the report is sent without an address.
class ReverseGeocoder {
  ReverseGeocoder({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<String?> addressOf(Coordinates position) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'format': 'jsonv2',
      'lat': position.latitude.toString(),
      'lon': position.longitude.toString(),
      'zoom': '18',
      'accept-language': 'it',
    });
    try {
      final response = await _client.get(
        uri,
        headers: {'User-Agent': 'VetApp/1.0 (com.vetapp.mobile_app)'},
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        return null;
      }
      final address = (jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>)['address'];
      if (address is! Map<String, dynamic>) {
        return null;
      }
      final street = [address['road'], address['house_number']].whereType<String>().join(' ');
      final town = address['city'] ?? address['town'] ?? address['village'] ?? address['municipality'];
      final parts = [if (street.isNotEmpty) street, if (town is String) town];
      return parts.isEmpty ? null : parts.join(', ');
    } catch (_) {
      return null;
    }
  }
}
