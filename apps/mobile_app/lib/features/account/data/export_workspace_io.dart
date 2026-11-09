import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'export_workspace.dart';

/// A temporary folder inside the app's own cache, removed by [dispose].
Future<ExportWorkspace> createExportWorkspace() async {
  final base = await getTemporaryDirectory();
  return DiskExportWorkspace.create(base);
}

class DiskExportWorkspace implements ExportWorkspace {
  DiskExportWorkspace._(this.root);

  /// A new, empty folder under [base].
  static Future<DiskExportWorkspace> create(Directory base) async {
    final root = await base.createTemp('quokka-export-');
    return DiskExportWorkspace._(root);
  }

  final Directory root;

  File _file(String relativePath) {
    // Only names made by the builder reach here; a path that climbs out of the
    // folder is refused anyway.
    final parts = relativePath.split('/');
    if (parts.any((part) => part.isEmpty || part == '.' || part == '..')) {
      throw ArgumentError.value(relativePath, 'relativePath', 'outside the export folder');
    }
    return File('${root.path}${Platform.pathSeparator}${parts.join(Platform.pathSeparator)}');
  }

  @override
  Future<void> write(String relativePath, Uint8List bytes) async {
    final file = _file(relativePath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
  }

  @override
  Future<Uint8List> read(String relativePath) => _file(relativePath).readAsBytes();

  @override
  Future<void> dispose() async {
    try {
      if (await root.exists()) await root.delete(recursive: true);
    } catch (_) {
      // Nothing more can be done; the folder is in the app's own cache.
    }
  }
}
