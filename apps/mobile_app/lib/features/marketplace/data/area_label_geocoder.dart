import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../location/domain/coordinates.dart';

/// Turns a listing's already-approximated position into a zone name
/// ("Navigli, Milano"), via OpenStreetMap's Nominatim like the Località
/// settings. Only the ~1 km grid point is ever sent, so not even the
/// geocoding service sees the seller's real position; zoom 14 asks for
/// neighbourhood level, and street/house number are never read.
abstract class AreaLabelResolver {
  Future<String?> areaLabelOf(Coordinates approximated);
}

class NominatimAreaLabelResolver implements AreaLabelResolver {
  NominatimAreaLabelResolver({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<String?> areaLabelOf(Coordinates approximated) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'format': 'jsonv2',
      'lat': approximated.latitude.toString(),
      'lon': approximated.longitude.toString(),
      'zoom': '14',
      'accept-language': 'it',
    });
    try {
      final response = await _client.get(
        uri,
        headers: {'User-Agent': 'VetApp/1.0 (com.vetapp.mobile_app)'},
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final address =
          (jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>)['address'];
      if (address is! Map<String, dynamic>) return null;
      return areaLabelFromAddress(address);
    } catch (_) {
      return null;
    }
  }
}

/// Neighbourhood + town from a Nominatim `address` object. Road, house
/// number and postcode are deliberately ignored.
String? areaLabelFromAddress(Map<String, dynamic> address) {
  String? first(List<String> keys) {
    for (final key in keys) {
      final value = address[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  final zone = first(['suburb', 'quarter', 'neighbourhood', 'city_district', 'hamlet']);
  final town = first(['city', 'town', 'village', 'municipality']);
  final parts = [if (zone != null) zone, if (town != null && town != zone) town];
  return parts.isEmpty ? null : parts.join(', ');
}
