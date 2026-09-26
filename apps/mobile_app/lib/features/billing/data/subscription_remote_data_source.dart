import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../shared/config/app_runtime_config_loader.dart';
import '../../../shared/errors/app_network_error.dart';
import '../../../shared/types/result.dart';
import '../../auth/data/auth_repository_factory.dart';
import '../domain/billing_models.dart';
import '../domain/subscription_status.dart';

abstract class SubscriptionRemoteDataSource {
  Future<Result<SubscriptionStatus>> fetchStatus();

  Future<Result<SubscriptionStatus>> selectPlan(PlanTier plan);
}

class HttpSubscriptionRemoteDataSource implements SubscriptionRemoteDataSource {
  HttpSubscriptionRemoteDataSource({
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
  Future<Result<SubscriptionStatus>> fetchStatus() async {
    try {
      final response = await _client
          .get(Uri.parse('$_baseUrl/subscription/status'), headers: _headers)
          .timeout(_timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return Result.failure(
          AppNetworkError(
            code: 'subscription_status_http_${response.statusCode}',
            message: 'Non sono riuscito a verificare il tuo abbonamento. Riprova.',
          ),
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return Result.success(SubscriptionStatus.fromJson(json));
    } on TimeoutException {
      return Result.failure<SubscriptionStatus>(
        const AppNetworkError(
          code: 'subscription_status_timeout',
          message: 'La richiesta ha impiegato troppo tempo. Riprova.',
        ),
      );
    } catch (e) {
      return Result.failure<SubscriptionStatus>(
        AppNetworkError(
          code: 'subscription_status_unexpected_error',
          message: "Qualcosa e' andato storto. Riprova.",
          details: e,
        ),
      );
    }
  }

  @override
  Future<Result<SubscriptionStatus>> selectPlan(PlanTier plan) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/subscription/select-plan'),
            headers: _headers,
            body: jsonEncode({'plan': plan.name}),
          )
          .timeout(_timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return Result.failure(
          AppNetworkError(
            code: 'subscription_select_plan_http_${response.statusCode}',
            message: 'Non sono riuscito a salvare il piano scelto. Riprova.',
          ),
        );
      }

      return fetchStatus();
    } on TimeoutException {
      return Result.failure<SubscriptionStatus>(
        const AppNetworkError(
          code: 'subscription_select_plan_timeout',
          message: 'La richiesta ha impiegato troppo tempo. Riprova.',
        ),
      );
    } catch (e) {
      return Result.failure<SubscriptionStatus>(
        AppNetworkError(
          code: 'subscription_select_plan_unexpected_error',
          message: "Qualcosa e' andato storto. Riprova.",
          details: e,
        ),
      );
    }
  }
}
