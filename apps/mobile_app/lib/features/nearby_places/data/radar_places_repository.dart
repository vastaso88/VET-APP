import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../shared/auth/current_user.dart';
import '../../../shared/config/app_runtime_config_loader.dart';
import '../../../shared/errors/app_network_error.dart';
import '../../../shared/types/result.dart';
import '../../location/domain/coordinates.dart';
import '../domain/radar_data_source.dart';
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
  // OpenStreetMap (the backend gives up after ~40 s); later ones hit the
  // cache and answer immediately.
  static const _timeout = Duration(seconds: 55);

  /// How many places per category to ask for. Generous close by, where the
  /// user expects to see everything; tighter on wide searches, where the
  /// full set would be thousands of rows. Clinics are never capped by the
  /// backend whatever this value.
  static int perTypeLimitFor(double radiusKm) {
    if (radiusKm <= 10) return 400;
    if (radiusKm <= 25) return 150;
    return 80;
  }

  /// Error code of a failure worth retrying automatically after a pause.
  static const preparingErrorCode = 'radar_places_preparing';

  /// Imported datasets with their release and date, plus the contact for
  /// corrections, for "Fonti dati". Empty when signed out or unreachable:
  /// the page then shows the fixed attribution alone.
  Future<RadarSourcesInfo> loadSources() async {
    const nothing = RadarSourcesInfo();
    final baseUrl = _configLoader.load().apiBaseUrl;
    final token = CurrentUser.accessToken();
    if (baseUrl.isEmpty || token == null || token.isEmpty) {
      return nothing;
    }
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/local-services/sources'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        return nothing;
      }
      final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final email = json['support_contact_email'];
      return RadarSourcesInfo(
        sources: (json['sources'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(RadarDataSource.tryFromJson)
            .whereType<RadarDataSource>()
            .toList(growable: false),
        supportContactEmail: email is String && email.trim().isNotEmpty ? email.trim() : null,
      );
    } catch (_) {
      return nothing;
    }
  }

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
        'per_type_limit': perTypeLimitFor(radiusKm).toString(),
      },
    );

    try {
      final response = await _client
          .get(uri, headers: {'Authorization': 'Bearer $token'}).timeout(_timeout);

      if (const {502, 503, 504}.contains(response.statusCode)) {
        // The backend could not import this area from OpenStreetMap right
        // now (busy or rate-limited provider). Usually clears on its own.
        return Result.failure(
          const AppNetworkError(
            code: preparingErrorCode,
            message: 'Sto ancora preparando i servizi di questa zona. Riprova tra poco.',
          ),
        );
      }
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
          code: preparingErrorCode,
          message: 'Sto ancora preparando i servizi di questa zona. Riprova tra poco.',
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

class RadarSourcesInfo {
  const RadarSourcesInfo({this.sources = const [], this.supportContactEmail});

  final List<RadarDataSource> sources;

  /// Where to ask for a correction or removal, as configured on the
  /// backend. Null when none is configured: the app then shows no address
  /// rather than one that may not be ours.
  final String? supportContactEmail;
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
