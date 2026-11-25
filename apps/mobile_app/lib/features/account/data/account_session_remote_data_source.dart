import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../l10n/l10n.dart';
import '../../../shared/auth/current_user.dart';
import '../../../shared/config/app_runtime_config_loader.dart';
import '../../../shared/errors/app_network_error.dart';
import '../../../shared/types/result.dart';

/// The code the backend answers for an account that was put in deletion from another device.
const kAccountDeactivatedCode = 'account_deactivated';

/// The cheap check the app makes when it opens or comes back to the front
/// (`GET /account/session`): it goes through the same guard as every route.
abstract class AccountSessionRemoteDataSource {
  /// Succeeds for a usable account; fails with the backend's code otherwise
  /// ([kAccountDeactivatedCode], ...).
  Future<Result<void>> checkSession();
}

class HttpAccountSessionRemoteDataSource implements AccountSessionRemoteDataSource {
  HttpAccountSessionRemoteDataSource({http.Client? client, AppRuntimeConfigLoader? configLoader})
      : _client = client ?? http.Client(),
        _configLoader = configLoader ?? const AppRuntimeConfigLoader();

  final http.Client _client;
  final AppRuntimeConfigLoader _configLoader;

  static const _timeout = Duration(seconds: 15);

  String get _baseUrl => _configLoader.load().apiBaseUrl;

  Map<String, String> get _headers {
    final token = CurrentUser.accessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  @override
  Future<Result<void>> checkSession() async {
    try {
      final response = await _client
          .get(Uri.parse('$_baseUrl/account/session'), headers: _headers)
          .timeout(_timeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return Result.success(null);
      }
      return Result.failure(
        AppNetworkError(
          code: _code(response.body) ?? 'account_session_http_${response.statusCode}',
          message: appL10n.authNetworkUnexpected,
        ),
      );
    } on TimeoutException {
      return Result.failure(
        AppNetworkError(code: 'account_session_timeout', message: appL10n.authNetworkTimeout),
      );
    } catch (error) {
      return Result.failure(
        AppNetworkError(
          code: 'account_session_unexpected_error',
          message: appL10n.authNetworkUnexpected,
          details: error,
        ),
      );
    }
  }

  String? _code(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded['code'] as String? : null;
    } catch (_) {
      return null;
    }
  }
}
