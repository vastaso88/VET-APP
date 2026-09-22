import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../shared/config/app_runtime_config_loader.dart';
import '../../../shared/errors/app_network_error.dart';
import '../../../shared/types/result.dart';
import '../../auth/data/auth_repository_factory.dart';

abstract class SpeechToTextRemoteDataSource {
  /// Uploads a recorded audio clip and returns its transcription — see
  /// `POST /speech-to-text` (backend contract from "Chat LLM interna
  /// VETAPP": multipart field "file", response `{"text": "..."}`).
  Future<Result<String>> transcribe({
    required Uint8List audioBytes,
    required String fileName,
  });
}

class HttpSpeechToTextRemoteDataSource implements SpeechToTextRemoteDataSource {
  HttpSpeechToTextRemoteDataSource({
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
  Future<Result<String>> transcribe({
    required Uint8List audioBytes,
    required String fileName,
  }) async {
    try {
      final token = _authRepositoryFactory.create().currentContext.session?.accessToken;
      final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/speech-to-text'))
        ..headers.addAll({
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        })
        ..files.add(http.MultipartFile.fromBytes('file', audioBytes, filename: fileName));

      final streamedResponse = await _client.send(request).timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return Result.failure(
          AppNetworkError(
            code: 'speech_to_text_http_${response.statusCode}',
            message: 'Non sono riuscito a trascrivere il messaggio vocale.',
          ),
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return Result.success(json['text'] as String? ?? '');
    } on TimeoutException {
      return Result.failure<String>(
        const AppNetworkError(
          code: 'speech_to_text_timeout',
          message: 'Richiesta scaduta. Riprova.',
        ),
      );
    } catch (e) {
      return Result.failure<String>(
        AppNetworkError(
          code: 'speech_to_text_unexpected_error',
          message: "Qualcosa e' andato storto. Riprova.",
          details: e,
        ),
      );
    }
  }
}
