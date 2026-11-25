import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../l10n/l10n.dart';
import '../../../shared/auth/current_user.dart';
import '../../../shared/config/app_runtime_config_loader.dart';
import '../../../shared/errors/app_network_error.dart';
import '../../../shared/types/result.dart';

/// Where an account stands in "delete with a period to change your mind":
/// [pending] = deactivated and waiting to be erased on [purgeAfter].
/// [graceDays] is the backend's setting (not a number kept in the app).
class DeletionStatus {
  const DeletionStatus({
    required this.pending,
    required this.graceDays,
    this.purgeAfter,
  });

  final bool pending;
  final int graceDays;
  final DateTime? purgeAfter;

  factory DeletionStatus.fromJson(Map<String, dynamic> json) => DeletionStatus(
        pending: json['pending'] == true,
        graceDays: (json['grace_days'] as num?)?.toInt() ?? 30,
        purgeAfter: DateTime.tryParse(json['purge_after'] as String? ?? '')?.toLocal(),
      );
}

abstract class AccountDeletionRemoteDataSource {
  Future<Result<DeletionStatus>> fetch();

  /// Cancels the deletion (needs a recent sign-in: the code `reauth_required`
  /// when the backend asks for one).
  Future<Result<DeletionStatus>> cancel();

  /// "Elimina subito": erases the account at once, for good. Needs a recent
  /// sign-in (`reauth_required` otherwise).
  Future<Result<void>> deleteNow();
}

class HttpAccountDeletionRemoteDataSource implements AccountDeletionRemoteDataSource {
  HttpAccountDeletionRemoteDataSource({http.Client? client, AppRuntimeConfigLoader? configLoader})
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
  Future<Result<DeletionStatus>> fetch() =>
      _send(() => _client.get(Uri.parse('$_baseUrl/account/deletion'), headers: _headers));

  @override
  Future<Result<DeletionStatus>> cancel() =>
      _send(() => _client.post(Uri.parse('$_baseUrl/account/deletion/cancel'), headers: _headers));

  @override
  Future<Result<void>> deleteNow() async {
    try {
      final response = await _client
          .delete(Uri.parse('$_baseUrl/account?immediate=true'), headers: _headers)
          .timeout(const Duration(seconds: 60));
      if (response.statusCode >= 200 && response.statusCode < 300) return Result.success(null);
      return Result.failure(
        AppNetworkError(
          code: response.statusCode == 401 ? 'reauth_required' : 'account_delete_now_http',
          message: appL10n.accountDeleteFailed,
        ),
      );
    } catch (error) {
      return Result.failure(
        AppNetworkError(
          code: 'account_delete_now_unexpected_error',
          message: appL10n.authNetworkUnexpected,
          details: error,
        ),
      );
    }
  }

  Future<Result<DeletionStatus>> _send(Future<http.Response> Function() request) async {
    try {
      final response = await request().timeout(_timeout);
      final json = _decode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300 && json != null) {
        return Result.success(DeletionStatus.fromJson(json));
      }
      return Result.failure(
        AppNetworkError(
          code: response.statusCode == 401
              ? 'reauth_required'
              : (json?['code'] as String? ?? 'account_deletion_http_${response.statusCode}'),
          message: appL10n.accountRestoreFailed,
        ),
      );
    } on TimeoutException {
      return Result.failure(
        AppNetworkError(code: 'account_deletion_timeout', message: appL10n.authNetworkTimeout),
      );
    } catch (error) {
      return Result.failure(
        AppNetworkError(
          code: 'account_deletion_unexpected_error',
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
