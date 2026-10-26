import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../l10n/l10n.dart';
import '../../../shared/auth/current_user.dart';
import '../../../shared/files/attachment_media_type.dart';
import '../../../shared/files/image_metadata.dart';
import '../../../shared/config/app_runtime_config_loader.dart';
import '../../../shared/errors/app_network_error.dart';
import '../../../shared/types/result.dart';
import 'chat_remote_data_source.dart' show quotaExceededMessage;

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

  /// Raw bytes for a previously uploaded attachment — see
  /// `GET /chat-attachments/{id}/file`. Used to re-fetch a file that isn't
  /// (or no longer is) in this session's local cache.
  Future<Result<Uint8List>> download(String attachmentId);
}

class HttpChatAttachmentRemoteDataSource implements ChatAttachmentRemoteDataSource {
  HttpChatAttachmentRemoteDataSource({
    http.Client? client,
    AppRuntimeConfigLoader? configLoader,
  })  : _client = client ?? http.Client(),
        _configLoader = configLoader ?? const AppRuntimeConfigLoader();

  final http.Client _client;
  final AppRuntimeConfigLoader _configLoader;

  static const _timeout = Duration(seconds: 30);

  String get _baseUrl => _configLoader.load().apiBaseUrl;

  @override
  Future<Result<ChatAttachmentUploadResult>> upload({
    required String petId,
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    try {
      final token = CurrentUser.accessToken();
      final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/chat-attachments'))
        ..headers.addAll({
          // The backend words its refusals (daily allowance) in this language.
          'Accept-Language': AppLocaleHolder.current.languageCode,
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        })
        ..fields['pet_id'] = petId
        ..files.add(http.MultipartFile.fromBytes(
          'file',
          stripImageMetadata(imageBytes),
          filename: fileName,
          contentType: attachmentMediaType(imageBytes, fileName),
        ));

      final streamedResponse = await _client.send(request).timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        // Today's readings are used up: the backend's own sentence, in the
        // user's language, instead of the generic upload error.
        final quota = quotaExceededMessage(response.body);
        if (quota != null) {
          return Result.failure(AppNetworkError(code: 'quota_exceeded', message: quota));
        }
        final detailCode = _detailCode(response.body);
        return Result.failure(
          AppNetworkError(
            code: detailCode ?? 'chat_attachment_http_${response.statusCode}',
            message: _messageFor(detailCode, response.statusCode),
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
        AppNetworkError(
          code: 'chat_attachment_timeout',
          message: appL10n.chatErrorRequestTimeout,
        ),
      );
    } on http.ClientException {
      return Result.failure<ChatAttachmentUploadResult>(
        AppNetworkError(
          code: 'chat_attachment_offline',
          message: appL10n.chatErrorAttachmentOffline,
        ),
      );
    } catch (e) {
      return Result.failure<ChatAttachmentUploadResult>(
        AppNetworkError(
          code: 'chat_attachment_unexpected_error',
          message: appL10n.chatErrorGeneric,
          details: e,
        ),
      );
    }
  }

  @override
  Future<Result<Uint8List>> download(String attachmentId) async {
    try {
      final token = CurrentUser.accessToken();
      final response = await _client.get(
        Uri.parse('$_baseUrl/chat-attachments/$attachmentId/file'),
        headers: {
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      ).timeout(_timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return Result.failure(
          AppNetworkError(
            code: 'chat_attachment_download_http_${response.statusCode}',
            message: appL10n.chatErrorAttachmentDownload,
          ),
        );
      }

      return Result.success(response.bodyBytes);
    } on TimeoutException {
      return Result.failure<Uint8List>(
        AppNetworkError(
          code: 'chat_attachment_download_timeout',
          message: appL10n.chatErrorRequestTimeout,
        ),
      );
    } catch (e) {
      return Result.failure<Uint8List>(
        AppNetworkError(
          code: 'chat_attachment_download_unexpected_error',
          message: appL10n.chatErrorGeneric,
          details: e,
        ),
      );
    }
  }
}

/// The backend's stable error code, taken from the start of a 400 `detail`
/// such as "pdf_unreadable: ...". Null when the body has no known shape.
String? _detailCode(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) return null;
    final detail = decoded['detail'];
    if (detail is! String) return null;
    final code = detail.split(':').first.trim();
    return _knownCodes.contains(code) ? code : null;
  } catch (_) {
    return null;
  }
}

const _knownCodes = {
  'attachment_too_large',
  'unsupported_attachment_type',
  'pdf_too_many_pages',
  'pdf_unreadable',
};

String _messageFor(String? detailCode, int statusCode) {
  switch (detailCode) {
    case 'attachment_too_large':
      return appL10n.chatErrorAttachmentTooLarge;
    case 'unsupported_attachment_type':
      return appL10n.chatErrorAttachmentUnsupported;
    case 'pdf_too_many_pages':
      return appL10n.chatErrorPdfTooManyPages;
    case 'pdf_unreadable':
      return appL10n.chatErrorPdfUnreadable;
  }
  if (statusCode == 413) return appL10n.chatErrorAttachmentTooLarge;
  return appL10n.chatErrorAttachmentUpload;
}
