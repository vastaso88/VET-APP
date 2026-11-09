import 'dart:typed_data';

import 'export_workspace_stub.dart' if (dart.library.io) 'export_workspace_io.dart' as platform;

/// Where the files of an export wait while the zip is built. On the phone it
/// is a folder inside the app's own temporary directory, deleted by
/// [dispose] whatever happens (success, error or cancel); on the web there is
/// no disk and the files stay in memory. Nothing is ever copied anywhere else.
abstract class ExportWorkspace {
  Future<void> write(String relativePath, Uint8List bytes);

  Future<Uint8List> read(String relativePath);

  /// Removes everything. Safe to call twice.
  Future<void> dispose();
}

/// The workspace of this platform.
Future<ExportWorkspace> createExportWorkspace() => platform.createExportWorkspace();

/// Memory only: tests and the web.
class MemoryExportWorkspace implements ExportWorkspace {
  final Map<String, Uint8List> _files = {};

  bool get isEmpty => _files.isEmpty;

  @override
  Future<void> write(String relativePath, Uint8List bytes) async => _files[relativePath] = bytes;

  @override
  Future<Uint8List> read(String relativePath) async => _files[relativePath]!;

  @override
  Future<void> dispose() async => _files.clear();
}
