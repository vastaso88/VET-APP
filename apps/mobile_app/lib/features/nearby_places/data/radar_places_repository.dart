import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../shared/auth/current_user.dart';
import '../../../shared/config/app_runtime_config_loader.dart';
import '../../../shared/errors/app_network_error.dart';
import '../../../shared/types/result.dart';
import '../../location/domain/coordinates.dart';
import '../domain/radar_place.dart';

/// Pet services around a point, from the backend's `/local-services/places`.
/// The backend caps the radius it can serve (see RADAR_SEARCH_RADIUS_KM),
/// so [RadarPlacesResult.searchRadiusKm] may be smaller than requested.
class RadarPlacesRepository {
  RadarPlacesRepository({http.Client? client, AppRuntimeConfigLoader? configLoader})
      : _client = client ?? http.Client(),
        _configLoader = configLoader ?? const AppRuntimeConfigLoader();

  final http.Client _client;
  final AppRuntimeConfigLoader _configLoader;

  // The first request for an area makes the backend import it from
  // OpenStreetMap, which can take tens of seconds; later ones hit the cache.
  static const _timeout = Duration(seconds: 45);

  Future<Result<RadarPlacesResult>> loadNearby({
    required Coordinates center,
    required double radiusKm,
    int limit = 60,
  }) async {
    final baseUrl = _configLoader.load().apiBaseUrl;
    final token = CurrentUser.accessToken();
    if (baseUrl.isEmpty || token == null || token.isEmpty) {
      return Result.failure(
        const AppNetworkError(
          code: 'radar_places_unavailable',
          message: 'Accedi per vedere i servizi per animali vicino a te.',
        ),
      );
    }

    final uri = Uri.parse('$baseUrl/local-services/places').replace(
      queryParameters: {
        'latitude': center.latitude.toString(),
        'longitude': center.longitude.toString(),
        'radius_km': radiusKm.toString(),
        'limit': limit.toString(),
      },
    );

    try {
      final response = await _client
          .get(uri, headers: {'Authorization': 'Bearer $token'}).timeout(_timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return Result.failure(
          AppNetworkError(
            code: 'radar_places_http_${response.statusCode}',
            message: 'Non sono riuscito a caricare i servizi vicini. Riprova.',
          ),
        );
      }

      final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final context = json['context'] as Map<String, dynamic>? ?? const {};
      final places = (json['places'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(RadarPlace.tryFromJson)
          .whereType<RadarPlace>()
          .toList(growable: false);
      return Result.success(
        RadarPlacesResult(
          places: places,
          searchRadiusKm: (context['search_radius_km'] as num?)?.toDouble() ?? radiusKm,
        ),
      );
    } on TimeoutException {
      return Result.failure<RadarPlacesResult>(
        const AppNetworkError(
          code: 'radar_places_timeout',
          message: 'La ricerca dei servizi vicini sta impiegando troppo. Riprova tra poco.',
        ),
      );
    } catch (e) {
      return Result.failure<RadarPlacesResult>(
        AppNetworkError(
          code: 'radar_places_unexpected_error',
          message: 'Non sono riuscito a caricare i servizi vicini. Riprova.',
          details: e,
        ),
      );
    }
  }
}

class RadarPlacesResult {
  const RadarPlacesResult({required this.places, required this.searchRadiusKm});

  final List<RadarPlace> places;
  final double searchRadiusKm;
}
