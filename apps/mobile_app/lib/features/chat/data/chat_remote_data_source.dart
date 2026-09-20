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
  /// Pets isn't wired to the backend yet (still demo-only), so this matches
  /// [fallbackName] against the account's existing backend pets by name, or
  /// creates one on the fly if none matches — just enough to unblock a real
  /// chat end-to-end without waiting on the full Pets integration. Matching
  /// by name (not just grabbing the first pet on the account) matters: a
  /// single account can have several local demo pets each chatting
  /// independently, and picking `.first` regardless of which pet the
  /// conversation is actually about silently attributed every message to
  /// whichever pet resolved first.
  Future<Result<String>> ensureDefaultPetId({
    required String fallbackName,
    required String fallbackSpecies,
  });

  Future<Result<void>> deleteConversation(String conversationId);
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
        // The backend enforces a max-active-conversations-per-pet limit and
        // reports it as a 400 with a `conversation_limit_reached: <msg>`
        // detail — a normal, expected outcome (not a real failure), so it's
        // surfaced with its own code and the backend's own user-facing
        // message instead of the generic network-error copy below.
        final detail = _extractDetail(response.body);
        if (detail != null && detail.startsWith('conversation_limit_reached')) {
          final colonIndex = detail.indexOf(':');
          return Result.failure(
            AppNetworkError(
              code: 'chat_conversation_limit_reached',
              message: colonIndex == -1 ? detail : detail.substring(colonIndex + 1).trim(),
            ),
          );
        }
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
        final normalizedFallback = fallbackName.trim().toLowerCase();
        for (final entry in pets) {
          final pet = entry as Map<String, dynamic>;
          final name = (pet['name'] as String?)?.trim().toLowerCase() ?? '';
          if (name == normalizedFallback) {
            return Result.success(pet['id'] as String);
          }
        }
        // No backend pet with this name yet — fall through to create one,
        // rather than reusing an unrelated pet's id.
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

  @override
  Future<Result<void>> deleteConversation(String conversationId) async {
    try {
      final response = await _client
          .delete(Uri.parse('$_baseUrl/conversations/$conversationId'), headers: _headers)
          .timeout(_timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return Result.failure(
          AppNetworkError(
            code: 'conversation_delete_http_${response.statusCode}',
            message: 'Non sono riuscito a eliminare la chat sul server.',
          ),
        );
      }
      return Result.success<void>(null);
    } on TimeoutException {
      return Result.failure<void>(
        const AppNetworkError(
          code: 'conversation_delete_timeout',
          message: 'Richiesta scaduta. Riprova.',
        ),
      );
    } catch (e) {
      return Result.failure<void>(
        AppNetworkError(
          code: 'conversation_delete_unexpected_error',
          message: "Qualcosa e' andato storto. Riprova.",
          details: e,
        ),
      );
    }
  }

  String? _extractDetail(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded['detail'] as String?;
      }
    } catch (_) {
      // Non-JSON body (e.g. a plain-text 502 from an upstream proxy):
      // fall through to the generic error below.
    }
    return null;
  }
}
