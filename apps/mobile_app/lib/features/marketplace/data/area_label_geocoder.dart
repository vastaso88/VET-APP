import 'package:http/http.dart' as http;

import '../../../l10n/l10n.dart';
import '../../../shared/auth/current_user.dart';
import '../../../shared/config/app_runtime_config_loader.dart';
import '../../location/data/address_geocoder.dart';
import '../../location/domain/coordinates.dart';

/// Turns a listing's already-approximated position into a zone name
/// ("Navigli, Milano"). Asked to VetApp's backend (POST /geocoding/reverse,
/// zoom 14 = neighbourhood), which queries OpenStreetMap's Nominatim on the
/// app's behalf: the provider never sees the user's IP address (security
/// audit APP-6), and only the ~1 km grid point is ever sent, so not even
/// the backend learns the seller's real position. Street, house number and
/// postcode are never read.
abstract class AreaLabelResolver {
  Future<String?> areaLabelOf(Coordinates approximated);
}

/// The name is kept from when the app called Nominatim directly.
class NominatimAreaLabelResolver implements AreaLabelResolver {
  NominatimAreaLabelResolver({
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
  Future<String?> areaLabelOf(Coordinates approximated) async {
    final json = await postToGeocodingBackend(
      _client,
      _configLoader,
      _accessToken,
      '/geocoding/reverse',
      {
        'latitude': approximated.latitude,
        'longitude': approximated.longitude,
        'zoom': 14,
        'language': AppLocaleHolder.current.languageCode,
      },
    );
    final result = json?['result'];
    final address = result is Map<String, dynamic> ? result['address'] : null;
    if (address is! Map<String, dynamic>) return null;
    return areaLabelFromAddress(address);
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
