import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../design_system/tokens/app_colors.dart';
import '../../../l10n/l10n.dart';
import '../../pets/domain/pet_models.dart';
import '../data/medical_records_repository.dart';
import '../data/pet_conditions_repository.dart';
import '../domain/history_event.dart';
import '../domain/pet_condition.dart';
import '../domain/record_category.dart';
import 'history_labels.dart';
import 'history_pdf.dart';
import 'record_category_labels.dart';

/// The category icons of the page (the same ones as the tiles) as small PNGs
/// for the PDF, by [historySymbolKey]. One that cannot be drawn is left out:
/// the category name next to it says the same.
Future<Map<String, Uint8List>> renderHistorySymbols({
  Color color = AppColors.primary,
  int size = 64,
}) async {
  final icons = <String, IconData>{
    for (final category in RecordCategory.values) category.key: category.icon,
    'condition': conditionIcon,
  };
  final symbols = <String, Uint8List>{};
  for (final entry in icons.entries) {
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final painter = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: String.fromCharCode(entry.value.codePoint),
          style: TextStyle(
            fontSize: size.toDouble(),
            fontFamily: entry.value.fontFamily,
            package: entry.value.fontPackage,
            color: color,
          ),
        ),
      )..layout();
      painter.paint(canvas,
          Offset((size - painter.width) / 2, (size - painter.height) / 2));
      final image = await recorder.endRecording().toImage(size, size);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data != null) symbols[entry.key] = data.buffer.asUint8List();
    } catch (_) {
      continue;
    }
  }
  return symbols;
}

/// How long the shared file is kept after the share sheet returns: the app
/// the owner picked (WhatsApp, mail...) may still be reading it.
const _tempFileGrace = Duration(seconds: 15);

const _exportFolder = 'vetapp_export';

/// Hands [bytes] to the system share sheet as a PDF named [fileName], then
/// deletes the temporary file. Nothing is uploaded: the file only exists on
/// the device, in the cache folder, until the share is over.
///
/// On the web there is no file system: the bytes are shared from memory.
/// [share], [tempDir] and [grace] exist for tests.
Future<void> sharePdfThenDelete(
  Uint8List bytes,
  String fileName, {
  Future<void> Function(XFile file)? share,
  Future<Directory> Function()? tempDir,
  Duration grace = _tempFileGrace,
}) async {
  Future<void> send(XFile file) => share != null
      ? share(file)
      : Share.shareXFiles([file], subject: fileName);

  if (kIsWeb) {
    await send(
        XFile.fromData(bytes, name: fileName, mimeType: 'application/pdf'));
    return;
  }

  final base = await (tempDir ?? getTemporaryDirectory)();
  final folder =
      Directory('${base.path}${Platform.pathSeparator}$_exportFolder');
  await folder.create(recursive: true);
  // Whatever an earlier export left behind (the app was closed meanwhile).
  await for (final leftover in folder.list()) {
    try {
      await leftover.delete(recursive: true);
    } catch (_) {
      continue;
    }
  }
  final file = File('${folder.path}${Platform.pathSeparator}$fileName');
  await file.writeAsBytes(bytes, flush: true);
  var shared = false;
  try {
    await send(XFile(file.path, name: fileName, mimeType: 'application/pdf'));
    shared = true;
  } finally {
    if (shared && grace > Duration.zero) await Future<void>.delayed(grace);
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // The next export sweeps the folder.
    }
  }
}

/// Builds the PDF with the whole history of [pet] and shares it. Everything
/// happens on the device. When the illnesses cannot be read the PDF still
/// goes out with the records, and the owner is told what is missing.
Future<void> exportPetHistory(
  BuildContext context, {
  required PetProfile pet,
  required List<MedicalRecordEntry> records,
  required List<PetConditionEntry>? conditions,
}) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(SnackBar(content: Text(l10n.medHistoryPreparing)));

  var illnesses = conditions;
  if (illnesses == null) {
    try {
      illnesses = await PetConditionsRepository().loadForPet(pet.id);
    } catch (_) {
      messenger.showSnackBar(
          SnackBar(content: Text(l10n.medHistoryConditionsMissing)));
    }
  }

  try {
    final events =
        buildHistoryEvents(records: records, conditions: illnesses ?? const []);
    final now = DateTime.now();
    final pdf = await buildHistoryPdf(
      pet: pet,
      events: events,
      exportedAt: now,
      l10n: l10n,
      symbols: await renderHistorySymbols(),
    );
    await sharePdfThenDelete(pdf, historyPdfFileName(pet.name, now));
  } catch (_) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.medHistoryExportFailed)));
  }
}
