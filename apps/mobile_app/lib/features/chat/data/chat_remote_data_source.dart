import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../shared/config/app_runtime_config_loader.dart';
import '../../../shared/errors/app_network_error.dart';
import '../../../shared/types/result.dart';
import '../../auth/data/auth_repository_factory.dart';

/// Parsed slice of the backend's `POST /chat` response that the mobile chat
/// feature actually needs — see `SendChatMessageOutput`
/// (packages/core/application/services/send_chat_message.py) for the full
/// contract.
class ChatSendResult {
  const ChatSendResult({
    required this.content,
    required this.aiGenerated,
    required this.backendConversationId,
  });

  final String content;
  final bool aiGenerated;
  final String backendConversationId;
}

abstract class ChatRemoteDataSource {
  Future<Result<ChatSendResult>> sendMessage({
    required String petId,
    String? conversationId,
    required String userMessage,
  });

  /// Resolves a real, backend-known pet id to attach chat messages to.
  /// Pets isn't wired to the backend yet (still demo-only), so this uses the
  /// first pet already on the account, or creates one from the given
  /// fallback name/species on the fly — just enough to unblock a real chat
  /// end-to-end without waiting on the full Pets integration.
  Future<Result<String>> ensureDefaultPetId({
    required String fallbackName,
    required String fallbackSpecies,
  });
}

class HttpChatRemoteDataSource implements ChatRemoteDataSource {
  HttpChatRemoteDataSource({
    http.Client? client,
    AppRuntimeConfigLoader? configLoader,
    AuthRepositoryFactory? authRepositoryFactory,
  })  : _client = client ?? http.Client(),
        _configLoader = configLoader ?? const AppRuntimeConfigLoader(),
        _authRepositoryFactory = authRepositoryFactory ?? const AuthRepositoryFactory();

  final http.Client _client;
  final AppRuntimeConfigLoader _configLoader;
  final AuthRepositoryFactory _authRepositoryFactory;

  static const _timeout = Duration(seconds: 25);

  String get _baseUrl => _configLoader.load().apiBaseUrl;

  Map<String, String> get _headers {
    final token = _authRepositoryFactory.create().currentContext.session?.accessToken;
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  @override
  Future<Result<ChatSendResult>> sendMessage({
    required String petId,
    String? conversationId,
    required String userMessage,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/chat'),
            headers: _headers,
            body: jsonEncode({
              'pet_id': petId,
              if (conversationId != null) 'conversation_id': conversationId,
              'user_message': userMessage,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return Result.failure(
          AppNetworkError(
            code: 'chat_http_${response.statusCode}',
            message: "Non sono riuscito a contattare l'assistente. Riprova.",
          ),
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final reply = json['reply'] as Map<String, dynamic>;
      final conversation = json['conversation'] as Map<String, dynamic>;
      return Result.success(
        ChatSendResult(
          content: reply['content'] as String? ?? '',
          aiGenerated: json['ai_generated'] as bool? ?? false,
          backendConversationId: conversation['id'] as String,
        ),
      );
    } on TimeoutException {
      return Result.failure<ChatSendResult>(
        const AppNetworkError(
          code: 'chat_timeout',
          message: 'La richiesta ha impiegato troppo tempo. Riprova.',
        ),
      );
    } catch (e) {
      return Result.failure<ChatSendResult>(
        AppNetworkError(
          code: 'chat_unexpected_error',
          message: "Qualcosa e' andato storto. Riprova.",
          details: e,
        ),
      );
    }
  }

  @override
  Future<Result<String>> ensureDefaultPetId({
    required String fallbackName,
    required String fallbackSpecies,
  }) async {
    try {
      final listResponse = await _client
          .get(Uri.parse('$_baseUrl/pets'), headers: _headers)
          .timeout(_timeout);
      if (listResponse.statusCode >= 200 && listResponse.statusCode < 300) {
        final json = jsonDecode(listResponse.body) as Map<String, dynamic>;
        final pets = json['pet_profiles'] as List<dynamic>? ?? const [];
        if (pets.isNotEmpty) {
          final first = pets.first as Map<String, dynamic>;
          return Result.success(first['id'] as String);
        }
      }

      final createResponse = await _client
          .post(
            Uri.parse('$_baseUrl/pets'),
            headers: _headers,
            body: jsonEncode({'name': fallbackName, 'species': fallbackSpecies}),
          )
          .timeout(_timeout);
      if (createResponse.statusCode < 200 || createResponse.statusCode >= 300) {
        return Result.failure(
          AppNetworkError(
            code: 'pet_bootstrap_http_${createResponse.statusCode}',
            message: 'Non sono riuscito a preparare il profilo del pet.',
          ),
        );
      }
      final createdJson = jsonDecode(createResponse.body) as Map<String, dynamic>;
      final petProfile = createdJson['pet_profile'] as Map<String, dynamic>;
      return Result.success(petProfile['id'] as String);
    } on TimeoutException {
      return Result.failure<String>(
        const AppNetworkError(code: 'pet_bootstrap_timeout', message: 'Richiesta scaduta. Riprova.'),
      );
    } catch (e) {
      return Result.failure<String>(
        AppNetworkError(
          code: 'pet_bootstrap_unexpected_error',
          message: "Qualcosa e' andato storto. Riprova.",
          details: e,
        ),
      );
    }
  }
}
