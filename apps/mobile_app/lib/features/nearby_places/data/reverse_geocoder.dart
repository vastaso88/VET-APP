import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../location/domain/address_format.dart';
import '../../location/domain/coordinates.dart';
import '../../../l10n/l10n.dart';

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
      'accept-language': AppLocaleHolder.current.languageCode,
    });
    try {
      final response = await _client.get(
        uri,
        headers: {'User-Agent': 'VetApp/1.0 (com.vetapp.mobile_app)'},
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        return null;
      }
      final address =
          (jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>)['address'];
      if (address is! Map<String, dynamic>) {
        return null;
      }
      final label = formatAddress(
        AddressParts.fromNominatim(address),
        address['country_code'] as String?,
      );
      return label.isEmpty ? null : label;
    } catch (_) {
      return null;
    }
  }
}
