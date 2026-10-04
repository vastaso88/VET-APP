import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../shared/auth/current_user.dart';
import '../../../shared/config/app_runtime_config_loader.dart';
import '../../../shared/errors/app_network_error.dart';
import '../../../shared/types/result.dart';
import '../../location/domain/coordinates.dart';
import '../domain/radar_community.dart';
import '../domain/radar_place.dart';

/// What "Segnala!" accepts right now, decided by the backend so it can
/// change without a new app build.
class RadarReportOptions {
  const RadarReportOptions({required this.enabled, required this.missingPlaceTypes});

  final bool enabled;
  final List<RadarPlaceType> missingPlaceTypes;
}

/// Outcome of a submitted report.
class RadarReportReceipt {
  const RadarReportReceipt({required this.countedAsConfirmation});

  /// The same thing had already been reported: this submission confirmed
  /// that report instead of creating a new one.
  final bool countedAsConfirmation;
}

/// Writes of the community layer: reports, votes on reports, dog-park
/// stars. Every call can fail with [rulesRequiredCode] until the user
/// accepts the contribution rules.
class RadarContributionsRepository {
  RadarContributionsRepository({http.Client? client, AppRuntimeConfigLoader? configLoader})
      : _client = client ?? http.Client(),
        _configLoader = configLoader ?? const AppRuntimeConfigLoader();

  final http.Client _client;
  final AppRuntimeConfigLoader _configLoader;

  static const rulesRequiredCode = 'contribution_rules_required';
  static const _timeout = Duration(seconds: 20);

  Future<RadarReportOptions> loadOptions() async {
    final result = await _send('GET', '/local-services/reports/options');
    return result.fold(
      onFailure: (_) => const RadarReportOptions(enabled: false, missingPlaceTypes: []),
      onSuccess: (json) => RadarReportOptions(
        enabled: json['enabled'] == true,
        missingPlaceTypes: (json['missing_place_types'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .map(radarPlaceTypeFromApi)
            .where((type) => type != RadarPlaceType.other)
            .toList(growable: false),
      ),
    );
  }

  Future<Result<RadarReportReceipt>> reportMissing({
    required RadarPlaceType type,
    required String name,
    required Coordinates position,
    String? addressLabel,
  }) {
    return _submit({
      'kind': 'missing',
      'place_type': radarPlaceTypeToApi(type),
      'name': name,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'address_label': addressLabel,
    });
  }

  Future<Result<RadarReportReceipt>> reportProblem(RadarPlace place, RadarProblem problem) {
    return _submit({
      'kind': problem.apiValue,
      'place_type': radarPlaceTypeToApi(place.type),
      'name': place.name,
      'latitude': place.location.latitude,
      'longitude': place.location.longitude,
      'target_source': place.sourceName,
      'target_source_id': place.sourceExternalId,
    });
  }

  Future<Result<void>> vote(String reportId, {required bool confirm}) async {
    final result = await _send(
      'POST',
      '/local-services/reports/$reportId/vote',
      body: {'vote': confirm ? 'confirm' : 'deny'},
    );
    return result.map((_) {});
  }

  Future<Result<void>> rate(RadarPlace place, int stars) async {
    final result = await _send(
      'PUT',
      '/local-services/ratings',
      body: {
        'source': place.sourceName,
        'source_id': place.sourceExternalId,
        'latitude': place.location.latitude,
        'longitude': place.location.longitude,
        'stars': stars,
      },
    );
    return result.map((_) {});
  }

  Future<Result<RadarReportReceipt>> _submit(Map<String, Object?> body) async {
    final result = await _send('POST', '/local-services/reports', body: body);
    return result.map(
      (json) => RadarReportReceipt(
        countedAsConfirmation: json['counted_as_confirmation'] == true,
      ),
    );
  }

  /// One authenticated JSON call. A failure carries the backend's own
  /// `code` (when it sent one) and its `detail` as the message, since
  /// those are written for the user ("Puoi fare al massimo 5...").
  Future<Result<Map<String, dynamic>>> _send(
    String method,
    String path, {
    Map<String, Object?>? body,
  }) async {
    final baseUrl = _configLoader.load().apiBaseUrl;
    final token = CurrentUser.accessToken();
    if (baseUrl.isEmpty || token == null || token.isEmpty) {
      return Result.failure(
        const AppNetworkError(
          code: 'radar_contribution_signed_out',
          message: 'Accedi per segnalare o votare.',
        ),
      );
    }
    try {
      final request = http.Request(method, Uri.parse('$baseUrl$path'))
        ..headers['Authorization'] = 'Bearer $token'
        ..headers['Content-Type'] = 'application/json';
      if (body != null) {
        request.body = jsonEncode(body);
      }
      final response = await http.Response.fromStream(await _client.send(request).timeout(_timeout));
      final decoded = response.bodyBytes.isEmpty ? null : jsonDecode(utf8.decode(response.bodyBytes));
      final json = decoded is Map<String, dynamic> ? decoded : const <String, dynamic>{};
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final detail = json['detail'];
        return Result.failure(
          AppNetworkError(
            code: json['code'] as String? ?? 'radar_contribution_http_${response.statusCode}',
            message: detail is String ? detail : 'Non sono riuscito a completare l’operazione. Riprova.',
          ),
        );
      }
      return Result.success(json);
    } on TimeoutException {
      return Result.failure(
        const AppNetworkError(
          code: 'radar_contribution_timeout',
          message: 'La richiesta ha impiegato troppo tempo. Riprova.',
        ),
      );
    } catch (e) {
      return Result.failure(
        AppNetworkError(
          code: 'radar_contribution_unexpected_error',
          message: 'Non sono riuscito a completare l’operazione. Riprova.',
          details: e,
        ),
      );
    }
  }
}
