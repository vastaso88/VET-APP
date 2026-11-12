import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../shared/config/app_runtime_config_loader.dart';

/// Lets the owner stop an export: checked between files and before the zip
/// is put together.
class ExportCancelToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;
}

/// Thrown when the owner cancelled; the work stops and the temporary files
/// are removed.
class ExportCancelled implements Exception {
  const ExportCancelled();

  @override
  String toString() => 'Export cancelled';
}

/// Downloads the files of the export from the signed links the backend put in
/// the JSON (valid 15 minutes).
abstract class ExportFileFetcher {
  /// The size in bytes of the file behind [url], or null when it is not known.
  Future<int?> sizeOf(String url);

  /// The file, or null when it could not be downloaded (expired link, network).
  Future<Uint8List?> download(String url);
}

class HttpExportFileFetcher implements ExportFileFetcher {
  HttpExportFileFetcher({http.Client? client, AppRuntimeConfigLoader? configLoader})
      : _client = client ?? http.Client(),
        _configLoader = configLoader ?? const AppRuntimeConfigLoader();

  final http.Client _client;
  final AppRuntimeConfigLoader _configLoader;

  static const _timeout = Duration(seconds: 45);

  /// Only https links to the storage host of the app are followed: a link in
  /// the data never sends the phone to another place.
  bool _allowed(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return false;
    final configured = Uri.tryParse(_configLoader.load().supabaseUrl);
    if (configured != null && configured.host.isNotEmpty) {
      return uri.host == configured.host;
    }
    return true;
  }

  @override
  Future<int?> sizeOf(String url) async {
    if (!_allowed(url)) return null;
    try {
      final response = await _client.head(Uri.parse(url)).timeout(_timeout);
      if (response.statusCode != 200) return null;
      return int.tryParse(response.headers['content-length'] ?? '');
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Uint8List?> download(String url) async {
    if (!_allowed(url)) return null;
    try {
      final response = await _client.get(Uri.parse(url)).timeout(_timeout);
      if (response.statusCode != 200) return null;
      return response.bodyBytes;
    } catch (_) {
      return null;
    }
  }
}
