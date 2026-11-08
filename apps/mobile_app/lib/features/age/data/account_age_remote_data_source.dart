import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../l10n/l10n.dart';
import '../../../shared/auth/current_user.dart';
import '../../../shared/config/app_runtime_config_loader.dart';
import '../../../shared/errors/app_network_error.dart';
import '../../../shared/types/result.dart';
import '../domain/age_status.dart';

/// Error code when the backend says this account is closed (declared age
/// under the minimum) - any route answers it.
const kUnderMinimumAgeCode = 'under_minimum_age';

abstract class AccountAgeRemoteDataSource {
  Future<Result<AgeStatus>> fetch();

  /// Declares the date of birth (once). Only the date goes out; the backend
  /// keeps it in its own table and never sends it back.
  Future<Result<AgeStatus>> declare(DateTime birthDate);

  /// A declared minor says they have a parent's authorisation for a paid plan.
  Future<Result<AgeStatus>> confirmGuardian();
}

class HttpAccountAgeRemoteDataSource implements AccountAgeRemoteDataSource {
  HttpAccountAgeRemoteDataSource({http.Client? client, AppRuntimeConfigLoader? configLoader})
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
  Future<Result<AgeStatus>> fetch() =>
      _send(() => _client.get(Uri.parse('$_baseUrl/account/age'), headers: _headers));

  @override
  Future<Result<AgeStatus>> declare(DateTime birthDate) {
    final iso = '${birthDate.year.toString().padLeft(4, '0')}-'
        '${birthDate.month.toString().padLeft(2, '0')}-'
        '${birthDate.day.toString().padLeft(2, '0')}';
    return _send(
      () => _client.post(
        Uri.parse('$_baseUrl/account/age'),
        headers: _headers,
        body: jsonEncode({'birth_date': iso}),
      ),
    );
  }

  @override
  Future<Result<AgeStatus>> confirmGuardian() => _send(
        () =>
            _client.post(Uri.parse('$_baseUrl/account/guardian-authorization'), headers: _headers),
      );

  Future<Result<AgeStatus>> _send(Future<http.Response> Function() request) async {
    try {
      final response = await request().timeout(_timeout);
      final json = _decode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300 && json != null) {
        return Result.success(AgeStatus.fromJson(json));
      }
      final code = json?['code'] as String?;
      return Result.failure(
        AppNetworkError(
          code: code ?? 'account_age_http_${response.statusCode}',
          message: appL10n.ageSaveFailed,
        ),
      );
    } on TimeoutException {
      return Result.failure(
        AppNetworkError(code: 'account_age_timeout', message: appL10n.authNetworkTimeout),
      );
    } catch (error) {
      return Result.failure(
        AppNetworkError(
          code: 'account_age_unexpected_error',
          message: appL10n.authNetworkUnexpected,
          details: error,
        ),
      );
    }
  }

  Map<String, dynamic>? _decode(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }
}
