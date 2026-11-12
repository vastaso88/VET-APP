import 'package:http/http.dart' as http;

import '../../../shared/auth/current_user.dart';
import '../../../shared/config/app_runtime_config_loader.dart';
import '../../location/data/address_geocoder.dart';
import '../../location/domain/address_format.dart';
import '../../location/domain/coordinates.dart';
import '../../../l10n/l10n.dart';

/// Street address of a point, through VetApp's backend (POST
/// /geocoding/reverse), which asks OpenStreetMap's Nominatim on the app's
/// behalf: the user's position and IP address never reach a third party
/// (security audit APP-6). One request per report or per chosen point.
/// Best-effort: null without a backend or a session and on any failure,
/// and the caller goes on without an address.
class ReverseGeocoder {
  ReverseGeocoder({
    http.Client? client,
    AppRuntimeConfigLoader? configLoader,
    String? Function()? accessToken,
  })  : _client = client ?? http.Client(),
        _configLoader = configLoader ?? const AppRuntimeConfigLoader(),
        _accessToken = accessToken ?? CurrentUser.accessToken;

  final http.Client _client;
  final AppRuntimeConfigLoader _configLoader;
  final String? Function() _accessToken;

  Future<String?> addressOf(Coordinates position) async {
    final json = await postToGeocodingBackend(
      _client,
      _configLoader,
      _accessToken,
      '/geocoding/reverse',
      {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'zoom': 18,
        'language': AppLocaleHolder.current.languageCode,
      },
    );
    final result = json?['result'];
    final address = result is Map<String, dynamic> ? result['address'] : null;
    if (address is! Map<String, dynamic>) {
      return null;
    }
    final label = formatAddress(
      AddressParts.fromNominatim(address),
      address['country_code'] as String?,
    );
    return label.isEmpty ? null : label;
  }
}
