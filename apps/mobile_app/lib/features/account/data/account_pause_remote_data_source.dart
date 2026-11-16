import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../l10n/l10n.dart';
import '../../../shared/auth/current_user.dart';
import '../../../shared/config/app_runtime_config_loader.dart';
import '../../../shared/errors/app_network_error.dart';
import '../../../shared/types/result.dart';

/// The backend refuses every route of an account that was paused from another
/// device with this code (403).
const kAccountPausedCode = 'account_paused';

/// ... and of one waiting to be erased (the restore page is the way back).
const kAccountDeactivatedCode = 'account_deactivated';

/// "The pause is over": told once after the owner signs in again
/// (docs/compliance/18 §3.2). [hasAccess] false = no plan, so the account is
/// "without a plan" and [dataKeptUntil] is the new day the data would be erased.
class PauseNotice {
  const PauseNotice({required this.hasAccess, this.dataKeptUntil});

  final bool hasAccess;
  final DateTime? dataKeptUntil;
}

abstract class AccountPauseRemoteDataSource {
  /// Null when there is nothing to say.
  Future<Result<PauseNotice?>> fetchNotice();

  /// The notice was shown: the backend forgets it.
  Future<Result<void>> acknowledgeNotice();

  /// A cheap authenticated call. A failure carries the backend's code
  /// ([kAccountPausedCode], [kAccountDeactivatedCode]) in [AppNetworkError.code].
  Future<Result<void>> checkSession();
}

class HttpAccountPauseRemoteDataSource implements AccountPauseRemoteDataSource {
  HttpAccountPauseRemoteDataSource({http.Client? client, AppRuntimeConfigLoader? configLoader})
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
  Future<Result<PauseNotice?>> fetchNotice() async {
    final result = await _send(
      () => _client.get(Uri.parse('$_baseUrl/account/pause/notice'), headers: _headers),
    );
    return result.fold(
      onSuccess: (json) => Result.success(
        json['resumed'] == true
            ? PauseNotice(
                hasAccess: json['has_access'] != false,
                dataKeptUntil:
                    DateTime.tryParse(json['data_kept_until'] as String? ?? '')?.toLocal(),
              )
            : null,
      ),
      onFailure: (error) => Result.failure(error),
    );
  }

  @override
  Future<Result<void>> acknowledgeNotice() async {
    final result = await _send(
      () => _client.post(Uri.parse('$_baseUrl/account/pause/notice/ack'), headers: _headers),
    );
    return result.fold(
      onSuccess: (_) => Result.success(null),
      onFailure: (error) => Result.failure(error),
    );
  }

  @override
  Future<Result<void>> checkSession() async {
    final result = await _send(
      () => _client.get(Uri.parse('$_baseUrl/account/session'), headers: _headers),
    );
    return result.fold(
      onSuccess: (_) => Result.success(null),
      onFailure: (error) => Result.failure(error),
    );
  }

  Future<Result<Map<String, dynamic>>> _send(Future<http.Response> Function() request) async {
    try {
      final response = await request().timeout(_timeout);
      final json = _decode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return Result.success(json ?? const {});
      }
      return Result.failure(
        AppNetworkError(
          code: json?['code'] as String? ?? 'account_pause_http_${response.statusCode}',
          message: appL10n.authNetworkUnexpected,
        ),
      );
    } on TimeoutException {
      return Result.failure(
        AppNetworkError(code: 'account_pause_timeout', message: appL10n.authNetworkTimeout),
      );
    } catch (error) {
      return Result.failure(
        AppNetworkError(
          code: 'account_pause_unexpected_error',
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
