import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../l10n/l10n.dart';
import '../../../shared/auth/current_user.dart';
import '../../../shared/config/app_runtime_config_loader.dart';
import '../../../shared/errors/app_network_error.dart';
import '../../../shared/types/result.dart';

/// What `GET /account/export` returned, ready to be saved as a file.
class AccountExportFile {
  const AccountExportFile({required this.fileName, required this.bytes});

  /// `quokka-dati-2026-10-28.json`.
  final String fileName;
  final Uint8List bytes;
}

/// The error code of a refused export: one request every 10 minutes
/// (docs/security/09_export_dati_contratto.md). Never retried automatically.
const accountExportRateLimitedCode = 'account_export_rate_limited';

abstract class AccountExportRemoteDataSource {
  Future<Result<AccountExportFile>> fetch();
}

/// The data of the signed-in owner (GDPR art. 15 and 20): one JSON with every
/// table the account deletion erases and signed links to the files, valid
/// 15 minutes. The answer is kept in memory only; it reaches the phone only
/// when the owner saves it with the system file picker.
class HttpAccountExportRemoteDataSource implements AccountExportRemoteDataSource {
  HttpAccountExportRemoteDataSource({
    http.Client? client,
    AppRuntimeConfigLoader? configLoader,
    String? Function()? tokenProvider,
    DateTime Function()? clock,
  })  : _client = client ?? http.Client(),
        _configLoader = configLoader ?? const AppRuntimeConfigLoader(),
        _tokenProvider = tokenProvider ?? CurrentUser.accessToken,
        _clock = clock ?? DateTime.now;

  final http.Client _client;
  final AppRuntimeConfigLoader _configLoader;
  final String? Function() _tokenProvider;
  final DateTime Function() _clock;

  /// The server takes a few seconds on an account with many files.
  static const _timeout = Duration(seconds: 60);

  @override
  Future<Result<AccountExportFile>> fetch() async {
    final token = _tokenProvider();
    try {
      final response = await _client.get(
        Uri.parse('${_configLoader.load().apiBaseUrl}/account/export'),
        headers: {
          'Accept': 'application/json',
          'Accept-Language': AppLocaleHolder.current.languageCode,
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      ).timeout(_timeout);

      if (response.statusCode == 429) {
        return Result.failure(
          AppNetworkError(
            code: accountExportRateLimitedCode,
            message: appL10n.accountExportRateLimited,
          ),
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return Result.failure(
          AppNetworkError(
            code: 'account_export_http_${response.statusCode}',
            message: appL10n.accountExportFailed,
          ),
        );
      }

      final now = _clock();
      final day = '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      return Result.success(
        AccountExportFile(
          fileName: 'quokka-dati-$day.json',
          bytes: response.bodyBytes,
        ),
      );
    } on TimeoutException {
      return Result.failure(
        AppNetworkError(code: 'account_export_timeout', message: appL10n.authNetworkTimeout),
      );
    } catch (error) {
      return Result.failure(
        AppNetworkError(
          code: 'account_export_unexpected_error',
          message: appL10n.accountExportFailed,
          details: error,
        ),
      );
    }
  }
}
