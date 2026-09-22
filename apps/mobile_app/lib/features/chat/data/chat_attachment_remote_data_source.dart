import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../shared/config/app_runtime_config_loader.dart';
import '../../../shared/errors/app_network_error.dart';
import '../../../shared/types/result.dart';
import '../../auth/data/auth_repository_factory.dart';

/// Parsed slice of `POST /chat-attachments`'s response (contract from "Chat
/// LLM interna VETAPP"): the photo is analyzed server-side, so the mobile
/// client only needs the id to later link it to a `/chat` message.
class ChatAttachmentUploadResult {
  const ChatAttachmentUploadResult({
    required this.id,
    required this.analysis,
    required this.analysisFailed,
  });

  final String id;
  final String? analysis;
  final bool analysisFailed;
}

abstract class ChatAttachmentRemoteDataSource {
  Future<Result<ChatAttachmentUploadResult>> upload({
    required String petId,
    required Uint8List imageBytes,
    required String fileName,
  });
}

class HttpChatAttachmentRemoteDataSource implements ChatAttachmentRemoteDataSource {
  HttpChatAttachmentRemoteDataSource({
    http.Client? client,
    AppRuntimeConfigLoader? configLoader,
    AuthRepositoryFactory? authRepositoryFactory,
  })  : _client = client ?? http.Client(),
        _configLoader = configLoader ?? const AppRuntimeConfigLoader(),
        _authRepositoryFactory = authRepositoryFactory ?? const AuthRepositoryFactory();

  final http.Client _client;
  final AppRuntimeConfigLoader _configLoader;
  final AuthRepositoryFactory _authRepositoryFactory;

  static const _timeout = Duration(seconds: 30);

  String get _baseUrl => _configLoader.load().apiBaseUrl;

  @override
  Future<Result<ChatAttachmentUploadResult>> upload({
    required String petId,
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    try {
      final token = _authRepositoryFactory.create().currentContext.session?.accessToken;
      final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/chat-attachments'))
        ..headers.addAll({
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        })
        ..fields['pet_id'] = petId
        ..files.add(http.MultipartFile.fromBytes('file', imageBytes, filename: fileName));

      final streamedResponse = await _client.send(request).timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return Result.failure(
          AppNetworkError(
            code: 'chat_attachment_http_${response.statusCode}',
            message: 'Non sono riuscito a caricare la foto.',
          ),
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final attachment = json['attachment'] as Map<String, dynamic>;
      return Result.success(
        ChatAttachmentUploadResult(
          id: attachment['id'] as String,
          analysis: attachment['analysis'] as String?,
          analysisFailed: attachment['analysis_failed'] as bool? ?? false,
        ),
      );
    } on TimeoutException {
      return Result.failure<ChatAttachmentUploadResult>(
        const AppNetworkError(
          code: 'chat_attachment_timeout',
          message: 'Richiesta scaduta. Riprova.',
        ),
      );
    } catch (e) {
      return Result.failure<ChatAttachmentUploadResult>(
        AppNetworkError(
          code: 'chat_attachment_unexpected_error',
          message: "Qualcosa e' andato storto. Riprova.",
          details: e,
        ),
      );
    }
  }
}
