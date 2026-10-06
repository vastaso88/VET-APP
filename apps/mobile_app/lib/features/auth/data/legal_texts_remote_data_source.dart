import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../shared/config/app_runtime_config_loader.dart';

/// Reads the public consent-text catalog (GET /legal/consents). No token is
/// sent: the signup screen needs these texts before any account exists.
class LegalTextsRemoteDataSource {
  LegalTextsRemoteDataSource({
    http.Client? client,
    AppRuntimeConfigLoader? configLoader,
  })  : _client = client ?? http.Client(),
        _configLoader = configLoader ?? const AppRuntimeConfigLoader();

  final http.Client _client;
  final AppRuntimeConfigLoader _configLoader;

  static const _timeout = Duration(seconds: 15);

  /// The full text for [consentKey], or null when it can't be loaded.
  Future<String?> fetchText(String consentKey) async {
    try {
      final baseUrl = _configLoader.load().apiBaseUrl;
      final response = await _client
          .get(Uri.parse('$baseUrl/legal/consents'))
          .timeout(_timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final catalog = json['catalog'] as Map<String, dynamic>;
      final entry = catalog[consentKey] as Map<String, dynamic>?;
      return entry?['text'] as String?;
    } catch (_) {
      return null;
    }
  }
}
