import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../domain/account_export_readme.dart';
import 'export_file_fetcher.dart';
import 'export_workspace.dart';

/// One file of `export['files']` that has a download link.
class ExportFileEntry {
  const ExportFileEntry({
    required this.storagePath,
    required this.url,
    required this.kind,
    required this.zipPath,
    required this.displayName,
  });

  final String storagePath;
  final String url;
  final String kind;

  /// `foto/001-cane.jpg` or `allegati/002-referto.pdf`.
  final String zipPath;
  final String displayName;
}

/// What the export carries, read from the JSON: the files to download and the
/// ones that have no link.
class ExportPlan {
  const ExportPlan({required this.files, required this.withoutLink});

  final List<ExportFileEntry> files;
  final List<MissingExportFile> withoutLink;

  int get count => files.length;
}

/// The zip when it is ready.
class AccountExportZip {
  const AccountExportZip({required this.bytes, required this.downloaded, required this.missing});

  final Uint8List bytes;
  final int downloaded;
  final List<MissingExportFile> missing;
}

/// What a person can safely call a file: letters, digits, dot, dash, underscore.
String sanitizeExportFileName(String name) {
  var base = name.split('/').last.split(r'\').last;
  base = base.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_').replaceAll(RegExp(r'\.{2,}'), '.');
  base = base.replaceAll(RegExp(r'^[._]+'), '');
  if (base.isEmpty) base = 'file';
  if (base.length > 60) {
    final dot = base.lastIndexOf('.');
    final extension = dot > 0 && base.length - dot <= 8 ? base.substring(dot) : '';
    base = '${base.substring(0, 60 - extension.length)}$extension';
  }
  return base;
}

/// Reads `export['files']` into a plan: photos and videos of the pets and the
/// profile photo go in `foto/`, chat attachments in `allegati/`. Names are
/// numbered so two files never collide.
ExportPlan planExport(Map<String, dynamic> export) {
  final files = <ExportFileEntry>[];
  final withoutLink = <MissingExportFile>[];
  var index = 0;
  for (final item in (export['files'] as List?) ?? const []) {
    if (item is! Map) continue;
    final path = '${item['path'] ?? ''}';
    final name = sanitizeExportFileName(path);
    final kind = '${item['kind'] ?? ''}';
    final url = item['url'];
    if (url is! String || url.isEmpty) {
      withoutLink.add(MissingExportFile(name: name, reason: '${item['note'] ?? 'no link'}'));
      continue;
    }
    index++;
    final folder = kind == 'chat_attachment' ? 'allegati' : 'foto';
    final prefix = index.toString().padLeft(3, '0');
    files.add(
      ExportFileEntry(
        storagePath: path,
        url: url,
        kind: kind,
        zipPath: '$folder/$prefix-$name',
        displayName: name,
      ),
    );
  }
  return ExportPlan(files: files, withoutLink: withoutLink);
}

/// The size the zip will have, as far as it can be known before starting.
class ExportEstimate {
  const ExportEstimate({required this.fileCount, required this.knownBytes, required this.unknownCount});

  final int fileCount;
  final int knownBytes;

  /// Files whose size the server did not say.
  final int unknownCount;
}

Future<ExportEstimate> estimateExport(
  ExportPlan plan,
  ExportFileFetcher fetcher, {
  ExportCancelToken? cancel,
}) async {
  var known = 0;
  var unknown = 0;
  final queue = List.of(plan.files);
  Future<void> worker() async {
    while (queue.isNotEmpty) {
      if (cancel?.isCancelled ?? false) throw const ExportCancelled();
      final entry = queue.removeLast();
      final size = await fetcher.sizeOf(entry.url);
      if (size == null) {
        unknown++;
      } else {
        known += size;
      }
    }
  }

  await Future.wait([for (var i = 0; i < 4; i++) worker()]);
  return ExportEstimate(fileCount: plan.count, knownBytes: known, unknownCount: unknown);
}

/// Builds the readable zip: `dati.json` exactly as the server sent it,
/// `leggimi.html` and the downloaded `foto/` and `allegati/`. A file that
/// cannot be downloaded does not stop the zip: it is listed in the page.
class AccountExportZipBuilder {
  AccountExportZipBuilder({
    required this.fetcher,
    required this.workspaceFactory,
    required this.labels,
    required this.formatDate,
  });

  final ExportFileFetcher fetcher;
  final Future<ExportWorkspace> Function() workspaceFactory;
  final ExportReadmeLabels labels;
  final ExportDateFormatter formatDate;

  /// The temporary files are removed in every case: done, failed or cancelled.
  Future<AccountExportZip> build({
    required Uint8List jsonBytes,
    required Map<String, dynamic> export,
    ExportCancelToken? cancel,
    void Function(int done, int total)? onProgress,
  }) async {
    final workspace = await workspaceFactory();
    try {
      void checkCancelled() {
        if (cancel?.isCancelled ?? false) throw const ExportCancelled();
      }

      final plan = planExport(export);
      final missing = [...plan.withoutLink];
      final links = <String, String>{};
      var done = 0;
      onProgress?.call(0, plan.count);

      final queue = List.of(plan.files);
      Future<void> worker() async {
        while (queue.isNotEmpty) {
          checkCancelled();
          final entry = queue.removeAt(0);
          final bytes = await fetcher.download(entry.url);
          checkCancelled();
          if (bytes == null) {
            missing.add(MissingExportFile(name: entry.displayName, reason: 'download'));
          } else {
            await workspace.write(entry.zipPath, bytes);
            links[entry.storagePath] = entry.zipPath;
          }
          done++;
          onProgress?.call(done, plan.count);
        }
      }

      await Future.wait([for (var i = 0; i < 3; i++) worker()]);
      checkCancelled();

      final html = renderExportReadme(
        export: export,
        labels: labels,
        fileLinks: links,
        missingFiles: missing,
        formatDate: formatDate,
      );

      final archive = Archive()
        ..addFile(ArchiveFile.bytes('dati.json', jsonBytes))
        ..addFile(ArchiveFile.bytes('leggimi.html', utf8.encode(html)));
      for (final path in links.values) {
        checkCancelled();
        archive.addFile(ArchiveFile.bytes(path, await workspace.read(path)));
      }
      checkCancelled();
      final bytes = ZipEncoder().encodeBytes(archive, level: DeflateLevel.bestSpeed);
      return AccountExportZip(bytes: bytes, downloaded: links.length, missing: missing);
    } finally {
      await workspace.dispose();
    }
  }
}
