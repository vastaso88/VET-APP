import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../shared/auth/current_user.dart';
import '../../../shared/config/app_runtime_config_loader.dart';
import '../../../shared/errors/app_network_error.dart';
import '../../../shared/types/result.dart';

/// `PUT /pets/{pet_id}/medical-record-consent` — the owner's per-pet decision
/// on whether the chat may read that pet's clinical records (spec v3 §18).
/// The backend stamps the consent text version and the timestamp itself.
class MedicalRecordConsentRemoteDataSource {
  MedicalRecordConsentRemoteDataSource({
    http.Client? client,
    AppRuntimeConfigLoader? configLoader,
  })  : _client = client ?? http.Client(),
        _configLoader = configLoader ?? const AppRuntimeConfigLoader();

  final http.Client _client;
  final AppRuntimeConfigLoader _configLoader;

  static const _timeout = Duration(seconds: 15);

  Future<Result<bool>> setGranted({required String petId, required bool granted}) async {
    try {
      final token = CurrentUser.accessToken();
      final response = await _client
          .put(
            Uri.parse('${_configLoader.load().apiBaseUrl}/pets/$petId/medical-record-consent'),
            headers: {
              'Content-Type': 'application/json',
              if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'granted': granted}),
          )
          .timeout(_timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return Result.failure<bool>(
          AppNetworkError(
            code: 'medical_record_consent_http_${response.statusCode}',
            message: 'Non sono riuscito a salvare il consenso. Riprova.',
          ),
        );
      }
      return Result.success(granted);
    } on TimeoutException {
      return Result.failure<bool>(
        const AppNetworkError(
          code: 'medical_record_consent_timeout',
          message: 'Connessione lenta. Il consenso non è stato salvato, riprova.',
        ),
      );
    } catch (e) {
      return Result.failure<bool>(
        AppNetworkError(
          code: 'medical_record_consent_offline',
          message: 'Sei offline: il consenso non è stato salvato. Riprova con la connessione.',
          details: e,
        ),
      );
    }
  }
}
