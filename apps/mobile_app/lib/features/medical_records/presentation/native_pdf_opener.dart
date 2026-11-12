import 'dart:io';
import 'dart:typed_data';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import 'pdf_open_outcome.dart';

/// Opens a PDF in the device's own viewer: the bytes go to a private temp
/// file and the platform's view intent is launched on it. Temp files older
/// than an hour are swept on every call, so nothing piles up.
Future<PdfOpenOutcome> openPdfNatively(Uint8List bytes, String name) async {
  final temp = await getTemporaryDirectory();
  final folder = Directory('${temp.path}/referti_aperti')..createSync(recursive: true);
  _sweepOlderThan(folder, const Duration(hours: 1));

  final safeName = name.replaceAll(RegExp(r'[\/:*?"<>|]'), '_');
  final file = File('${folder.path}/${DateTime.now().microsecondsSinceEpoch}_$safeName');
  await file.writeAsBytes(bytes, flush: true);

  final result = await OpenFilex.open(file.path, type: 'application/pdf');
  return switch (result.type) {
    ResultType.done => PdfOpenOutcome.opened,
    ResultType.noAppToOpen => PdfOpenOutcome.noApp,
    _ => PdfOpenOutcome.failed,
  };
}

void _sweepOlderThan(Directory folder, Duration age) {
  final cutoff = DateTime.now().subtract(age);
  for (final entity in folder.listSync()) {
    if (entity is File && entity.statSync().modified.isBefore(cutoff)) {
      try {
        entity.deleteSync();
      } catch (_) {
        // A file still held by a viewer is left for the next sweep.
      }
    }
  }
}
