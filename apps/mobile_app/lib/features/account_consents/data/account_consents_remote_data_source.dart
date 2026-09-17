import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../shared/config/app_runtime_config_loader.dart';
import '../../../shared/errors/app_network_error.dart';
import '../../../shared/types/result.dart';
import '../../auth/data/auth_repository_factory.dart';
import '../domain/account_consent_models.dart';

abstract class AccountConsentsRemoteDataSource {
  Future<Result<AccountConsentsSnapshot>> fetch();

  Future<Result<AccountConsentsSnapshot>> setConsent({
    required String consentKey,
    required bool granted,
  });
}

class HttpAccountConsentsRemoteDataSource implements AccountConsentsRemoteDataSource {
  HttpAccountConsentsRemoteDataSource({
    http.Client? client,
    AppRuntimeConfigLoader? configLoader,
    AuthRepositoryFactory? authRepositoryFactory,
  })  : _client = client ?? http.Client(),
        _configLoader = configLoader ?? const AppRuntimeConfigLoader(),
        _authRepositoryFactory = authRepositoryFactory ?? const AuthRepositoryFactory();

  final http.Client _client;
  final AppRuntimeConfigLoader _configLoader;
  final AuthRepositoryFactory _authRepositoryFactory;

  static const _timeout = Duration(seconds: 15);

  String get _baseUrl => _configLoader.load().apiBaseUrl;

  Map<String, String> get _headers {
    final token = _authRepositoryFactory.create().currentContext.session?.accessToken;
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  @override
  Future<Result<AccountConsentsSnapshot>> fetch() async {
    try {
      final response = await _client
          .get(Uri.parse('$_baseUrl/account/consents'), headers: _headers)
          .timeout(_timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return Result.failure(
          AppNetworkError(
            code: 'account_consents_http_${response.statusCode}',
            message: 'Non sono riuscito a leggere i tuoi consensi. Riprova.',
          ),
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return Result.success(AccountConsentsSnapshot.fromJson(json));
    } on TimeoutException {
      return Result.failure<AccountConsentsSnapshot>(
        const AppNetworkError(
          code: 'account_consents_timeout',
          message: 'La richiesta ha impiegato troppo tempo. Riprova.',
        ),
      );
    } catch (e) {
      return Result.failure<AccountConsentsSnapshot>(
        AppNetworkError(
          code: 'account_consents_unexpected_error',
          message: "Qualcosa e' andato storto. Riprova.",
          details: e,
        ),
      );
    }
  }

  @override
  Future<Result<AccountConsentsSnapshot>> setConsent({
    required String consentKey,
    required bool granted,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/account/consents'),
            headers: _headers,
            body: jsonEncode({'consent_key': consentKey, 'granted': granted}),
          )
          .timeout(_timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return Result.failure(
          AppNetworkError(
            code: 'account_consents_set_http_${response.statusCode}',
            message: 'Non sono riuscito a salvare la tua scelta. Riprova.',
          ),
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return Result.success(AccountConsentsSnapshot.fromJson(json));
    } on TimeoutException {
      return Result.failure<AccountConsentsSnapshot>(
        const AppNetworkError(
          code: 'account_consents_set_timeout',
          message: 'La richiesta ha impiegato troppo tempo. Riprova.',
        ),
      );
    } catch (e) {
      return Result.failure<AccountConsentsSnapshot>(
        AppNetworkError(
          code: 'account_consents_set_unexpected_error',
          message: "Qualcosa e' andato storto. Riprova.",
          details: e,
        ),
      );
    }
  }
}
