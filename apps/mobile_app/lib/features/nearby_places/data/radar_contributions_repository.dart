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
import '../../../l10n/l10n.dart';

/// What "Segnala!" accepts right now, decided by the backend so it can
/// change without a new app build.
class RadarReportOptions {
  const RadarReportOptions({
    required this.enabled,
    required this.missingPlaceTypes,
    this.problems = RadarProblem.values,
    this.expiryDays = 7,
  });

  final bool enabled;
  final List<RadarPlaceType> missingPlaceTypes;

  /// What can be reported about an existing place right now.
  final List<RadarProblem> problems;

  /// A report nobody confirms within this many days is deleted.
  final int expiryDays;
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
      onFailure: (_) =>
          const RadarReportOptions(enabled: false, missingPlaceTypes: [], problems: []),
      onSuccess: (json) => RadarReportOptions(
        enabled: json['enabled'] == true,
        missingPlaceTypes: (json['missing_place_types'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .map(radarPlaceTypeFromApi)
            .where((type) => type != RadarPlaceType.other)
            .toList(growable: false),
        problems: _problems(json),
        expiryDays: (json['expiry_days'] as num?)?.toInt() ?? 7,
      ),
    );
  }

  /// A backend that does not list the kinds yet accepts them all.
  static List<RadarProblem> _problems(Map<String, dynamic> json) {
    if (json['enabled'] != true) {
      return const [];
    }
    final kinds = json['report_kinds'];
    if (kinds is! List) {
      return RadarProblem.values;
    }
    return RadarProblem.values
        .where((problem) => kinds.contains(problem.apiValue))
        .toList(growable: false);
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

  /// Takes back a report the user made themself, while it is pending.
  Future<Result<void>> withdraw(String reportId) async {
    final result = await _send('DELETE', '/local-services/reports/$reportId');
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
        AppNetworkError(
          code: 'radar_contribution_signed_out',
          message: appL10n.placesErrSignedOutContribute,
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
      final response =
          await http.Response.fromStream(await _client.send(request).timeout(_timeout));
      final decoded =
          response.bodyBytes.isEmpty ? null : jsonDecode(utf8.decode(response.bodyBytes));
      final json = decoded is Map<String, dynamic> ? decoded : const <String, dynamic>{};
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final detail = json['detail'];
        return Result.failure(
          AppNetworkError(
            code: json['code'] as String? ?? 'radar_contribution_http_${response.statusCode}',
            message: detail is String
                ? localizedBackendMessage(detail)
                : appL10n.placesErrOperationFailed,
          ),
        );
      }
      return Result.success(json);
    } on TimeoutException {
      return Result.failure(
        AppNetworkError(
          code: 'radar_contribution_timeout',
          message: appL10n.placesErrTimeout,
        ),
      );
    } catch (e) {
      return Result.failure(
        AppNetworkError(
          code: 'radar_contribution_unexpected_error',
          message: appL10n.placesErrOperationFailed,
          details: e,
        ),
      );
    }
  }
}

/// Known messages of the backend's `detail` field (written in Italian
/// there), shown in the app language. An unknown message is returned as
/// received.
String localizedBackendMessage(String raw) {
  final l10n = appL10n;
  final text = raw.trim();
  final key = text.toLowerCase();
  final known = <String, String>{
    'per segnalare o votare accetta prima le regole per segnalazioni e voti.':
        l10n.placesBackendRulesRequired,
    'questa segnalazione è già stata chiusa.': l10n.placesBackendReportClosed,
    "questa segnalazione è scaduta: nessuno l'ha confermata.": l10n.placesBackendReportExpired,
    'non puoi confermare una tua segnalazione.': l10n.placesBackendOwnReportVote,
    'questo tipo di segnalazione non è attivo.': l10n.placesBackendKindNotActive,
    'questa categoria non può essere segnalata.': l10n.placesBackendCategoryNotReportable,
    'indica il luogo a cui si riferisce la segnalazione.': l10n.placesBackendTargetRequired,
    'per un luogo in attesa di conferma usa "non è così" sulla sua scheda.':
        l10n.placesBackendPendingUseDeny,
    'hai già fatto questa segnalazione.': l10n.placesBackendAlreadyReported,
    'segnalazione non trovata.': l10n.placesBackendReportNotFound,
    'puoi ritirare solo una tua segnalazione.': l10n.placesBackendWithdrawOwnOnly,
    'questa segnalazione è già chiusa: non si può più ritirare.': l10n.placesBackendWithdrawClosed,
    'le valutazioni non sono attive.': l10n.placesBackendRatingsOff,
    'si possono valutare solo le aree cani pubbliche.': l10n.placesBackendRatePublicOnly,
    'area cani non trovata.': l10n.placesBackendDogParkNotFound,
    'segnalazioni e voti non sono ancora attivi.': l10n.placesBackendContributionsOff,
    "scrivi il nome dell'attività, come appare sull'insegna.": l10n.placesBackendNameRequired,
    'nel nome non inserire telefoni, email o siti web.': l10n.placesBackendNameNoContacts,
    'il nome contiene parole non ammesse.': l10n.placesBackendNameBlockedWords,
  };
  final exact = known[key];
  if (exact != null) {
    return exact;
  }
  final limit = RegExp(r'^puoi fare al massimo (\d+) segnalazioni al giorno\.$').firstMatch(key);
  if (limit != null) {
    return l10n.placesBackendDailyLimit(int.parse(limit.group(1)!));
  }
  final length = RegExp(r'^il nome può avere al massimo (\d+) caratteri\.$').firstMatch(key);
  if (length != null) {
    return l10n.placesBackendNameTooLong(int.parse(length.group(1)!));
  }
  return raw;
}
