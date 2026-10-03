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
/// The radius is honored by the backend up to its configured maximum
/// (RADAR_SEARCH_RADIUS_KM); [RadarPlacesResult.searchRadiusKm] reports the
/// radius actually served.
class RadarPlacesRepository {
  RadarPlacesRepository({http.Client? client, AppRuntimeConfigLoader? configLoader})
      : _client = client ?? http.Client(),
        _configLoader = configLoader ?? const AppRuntimeConfigLoader();

  final http.Client _client;
  final AppRuntimeConfigLoader _configLoader;

  // The first request for an area makes the backend import it from
  // OpenStreetMap (up to ~60 s for the widest radius); later ones hit the
  // cache and answer immediately.
  static const _timeout = Duration(seconds: 75);

  /// The backend returns up to this many places per category, nearest
  /// first, so abundant categories (dog parks) cannot crowd out scarce
  /// ones (clinics).
  static const perTypeLimit = 40;

  Future<Result<RadarPlacesResult>> loadNearby({
    required Coordinates center,
    required double radiusKm,
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
        'per_type_limit': perTypeLimit.toString(),
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
      final coverage = json['coverage'] as Map<String, dynamic>? ?? const {};
      final places = (json['places'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(RadarPlace.tryFromJson)
          .whereType<RadarPlace>()
          .toList(growable: false);
      return Result.success(
        RadarPlacesResult(
          places: places,
          searchRadiusKm: (context['search_radius_km'] as num?)?.toDouble() ?? radiusKm,
          isStale: coverage['status'] == 'stale',
          refreshedAt: DateTime.tryParse(coverage['refreshed_at'] as String? ?? ''),
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
  const RadarPlacesResult({
    required this.places,
    required this.searchRadiusKm,
    this.isStale = false,
    this.refreshedAt,
  });

  final List<RadarPlace> places;
  final double searchRadiusKm;

  /// True when the backend could not refresh an expired area and is
  /// serving its previous import.
  final bool isStale;
  final DateTime? refreshedAt;
}
