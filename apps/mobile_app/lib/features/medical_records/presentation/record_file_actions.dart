import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_text_styles.dart';
import '../../../shared/files/attachment_media_type.dart';
import '../../chat/data/chat_attachment_remote_data_source.dart';
import '../data/medical_record_file_cache.dart';
import '../data/medical_records_repository.dart';
import 'native_pdf_opener_stub.dart' if (dart.library.io) 'native_pdf_opener.dart';
import 'pdf_open_outcome.dart';

/// The bytes of a record's file: this session's cache first, then the server.
/// Null when the record has no file, or the file can't be reached right now.
Future<Uint8List?> loadRecordBytes(MedicalRecordEntry record) async {
  final cached = MedicalRecordFileCache.instance.get(record.id);
  if (cached != null) return cached.bytes;
  final attachmentId = record.attachmentId;
  if (attachmentId == null) return null;
  final result = await HttpChatAttachmentRemoteDataSource().download(attachmentId);
  return result.fold(onSuccess: (bytes) => bytes, onFailure: (_) => null);
}

String _mimeFor(Uint8List bytes, String name) => attachmentMediaType(bytes, name).toString();

/// Opens the sheet with the actions for one record: Apri, Invia, Elimina.
Future<void> showRecordActions(
  BuildContext context, {
  required MedicalRecordEntry record,
  required VoidCallback onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
            child: Text(record.title, style: AppTextStyles.title, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
          ListTile(
            leading: const Icon(Icons.open_in_new_rounded),
            title: const Text('Apri'),
            onTap: () {
              Navigator.of(sheetContext).pop();
              openRecordFile(context, record);
            },
          ),
          ListTile(
            leading: const Icon(Icons.ios_share_rounded),
            title: const Text('Invia'),
            onTap: () {
              Navigator.of(sheetContext).pop();
              shareRecords(context, [record]);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text('Elimina'),
            onTap: () {
              Navigator.of(sheetContext).pop();
              deleteRecordWithConfirm(context, record: record, onDeleted: onChanged);
            },
          ),
        ],
      ),
    ),
  );
}

/// Images open full-screen. A PDF has no in-app viewer here, so "Apri" hands
/// it to the system: the share sheet offers "Apri con" on Android and the
/// browser's own PDF view on web.
Future<void> openRecordFile(BuildContext context, MedicalRecordEntry record) async {
  final bytes = await loadRecordBytes(record);
  if (!context.mounted) return;
  if (bytes == null) {
    _showMessage(context, 'Il file non è disponibile ora. Controlla la connessione e riprova.');
    return;
  }
  final mime = _mimeFor(bytes, record.title);
  if (mime.startsWith('image/')) {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => RecordImageViewer(bytes: bytes, title: record.title)),
    );
    return;
  }
  final outcome = await openPdfNatively(bytes, record.title);
  if (!context.mounted) return;
  switch (outcome) {
    case PdfOpenOutcome.opened:
      return;
    case PdfOpenOutcome.noApp:
      await _offerShareInstead(context, record);
    case PdfOpenOutcome.failed:
      _showMessage(context, 'Non sono riuscito ad aprire il PDF. Riprova oppure usa Invia.');
    case PdfOpenOutcome.unsupported:
      // Web: the browser's share/viewer path.
      await Share.shareXFiles(
        [XFile.fromData(bytes, name: record.title, mimeType: mime)],
        text: record.title,
      );
  }
}

Future<void> _offerShareInstead(BuildContext context, MedicalRecordEntry record) async {
  final share = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Nessuna app per aprire il PDF'),
      content: const Text(
        'Su questo dispositivo non c\'è un\'app che apre i PDF. Puoi inviare il file a un\'app che lo apre.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Chiudi'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Invia'),
        ),
      ],
    ),
  );
  if (share == true && context.mounted) {
    await shareRecords(context, [record]);
  }
}

/// Sends one or several records' files through the system share sheet.
Future<void> shareRecords(BuildContext context, List<MedicalRecordEntry> records) async {
  final files = <XFile>[];
  var missing = 0;
  for (final record in records) {
    final bytes = await loadRecordBytes(record);
    if (bytes == null) {
      missing++;
      continue;
    }
    files.add(XFile.fromData(bytes, name: record.title, mimeType: _mimeFor(bytes, record.title)));
  }
  if (!context.mounted) return;
  if (files.isEmpty) {
    _showMessage(context, 'Nessun file disponibile da inviare. Controlla la connessione e riprova.');
    return;
  }
  if (missing > 0) {
    _showMessage(context, '$missing file non disponibili non sono stati inclusi.');
  }
  await Share.shareXFiles(files);
}

/// Deletes a record after confirmation; a refused delete is shown, not hidden.
Future<void> deleteRecordWithConfirm(
  BuildContext context, {
  required MedicalRecordEntry record,
  required VoidCallback onDeleted,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Eliminare questo documento?'),
      content: Text('"${record.title}" verrà eliminato definitivamente.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Elimina'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  try {
    await MedicalRecordsRepository().deleteRecord(record.id);
  } on MedicalRecordSaveException catch (error) {
    if (context.mounted) _showMessage(context, error.message);
    return;
  }
  onDeleted();
}

void _showMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

/// Full-screen view of an image record, with pinch to zoom.
class RecordImageViewer extends StatelessWidget {
  const RecordImageViewer({required this.bytes, required this.title, super.key});

  final Uint8List bytes;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: InteractiveViewer(
        minScale: 1,
        maxScale: 4,
        child: Center(child: Image.memory(bytes, fit: BoxFit.contain)),
      ),
    );
  }
}
