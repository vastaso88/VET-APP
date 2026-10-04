import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../shared/files/attachment_media_type.dart';
import '../../../../shared/widgets/pet_loader.dart';


import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../chat/data/chat_attachment_remote_data_source.dart';
import '../../../pets/data/pet_demo_store.dart';
import '../../data/medical_record_file_cache.dart';
import '../../data/medical_records_repository.dart';

/// Real file-picker upload flow for a pet's cartella clinica: the user
/// picks an actual file from their device, we show its real name/size,
/// and save it as a new record. Images (jpg/jpeg/png) are uploaded for
/// real via the existing chat-attachments pipeline (same Supabase Storage
/// bucket/backend route as chat photos — see
/// HttpChatAttachmentRemoteDataSource), so they survive a reload. PDFs
/// have no matching backend endpoint yet, so those still only live in
/// [MedicalRecordFileCache] for this session (enough for "Invia file" to
/// share the real file right after uploading it, same as before).
class MedicalRecordUploadPage extends StatefulWidget {
  const MedicalRecordUploadPage({super.key, required this.petName});

  final String petName;

  @override
  State<MedicalRecordUploadPage> createState() => _MedicalRecordUploadPageState();
}

class _MedicalRecordUploadPageState extends State<MedicalRecordUploadPage> {
  final _repository = MedicalRecordsRepository();
  final _attachmentDataSource = HttpChatAttachmentRemoteDataSource();
  PlatformFile? _picked;
  bool _saving = false;

  static const _imageExtensions = {'jpg', 'jpeg', 'png', 'webp'};

  // Backend rejections of the file itself: retrying or saving locally would
  // only hide the reason, so these stop the save with their message.
  static const _validationCodes = {
    'attachment_too_large',
    'unsupported_attachment_type',
    'pdf_too_many_pages',
    'pdf_unreadable',
  };

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() => _picked = result.files.single);
  }

  Future<void> _save() async {
    final picked = _picked;
    if (picked == null || _saving) return;

    final bytes = picked.bytes;
    if (bytes != null) {
      final validationError = attachmentValidationError(bytes, picked.name);
      if (validationError != null) {
        _showMessage(validationError);
        return;
      }
    }

    setState(() => _saving = true);

    String? attachmentId;
    var analysisFailed = false;
    var uploadFailed = false;
    String? uploadError;
    String? rejectionMessage;
    if (bytes != null && _isUploadableFile(picked)) {
      await PetDemoStore.instance.ensureHydrated();
      final petId = PetDemoStore.instance.byName(widget.petName)?.id;
      if (petId == null) {
        uploadFailed = true;
      } else {
        final result = await _attachmentDataSource.upload(
          petId: petId,
          imageBytes: bytes,
          fileName: picked.name,
        );
        result.fold(
          onSuccess: (uploaded) {
            attachmentId = uploaded.id;
            analysisFailed = uploaded.analysisFailed;
          },
          onFailure: (error) {
            if (_validationCodes.contains(error.code)) {
              rejectionMessage = error.message;
            } else {
              uploadFailed = true;
              uploadError = error.message;
            }
          },
        );
        if (rejectionMessage != null) {
          setState(() => _saving = false);
          _showMessage(rejectionMessage!);
          return;
        }
      }
    }

    if (!mounted) return;
    if (uploadFailed) {
      setState(() => _saving = false);
      final choice = await _askUploadFailed(uploadError);
      if (!mounted) return;
      switch (choice) {
        case _UploadFailedChoice.retry:
          await _save();
        case _UploadFailedChoice.saveLocalOnly:
          await _persistRecord(attachmentId: null, uploadFailed: true, analysisFailed: false);
        case _UploadFailedChoice.cancel:
          break;
      }
      return;
    }

    await _persistRecord(
      attachmentId: attachmentId,
      uploadFailed: false,
      analysisFailed: analysisFailed,
    );
  }

  Future<void> _persistRecord({
    required String? attachmentId,
    required bool uploadFailed,
    required bool analysisFailed,
  }) async {
    final picked = _picked;
    if (picked == null) return;
    setState(() => _saving = true);

    final now = DateTime.now();
    final id = 'upload-${now.microsecondsSinceEpoch}';
    final bytes = picked.bytes;

    final record = MedicalRecordEntry(
      id: id,
      petName: widget.petName,
      title: picked.name,
      subtitle: '${_extensionLabel(picked.extension)} · ${_formatSize(picked.size)}',
      meta: uploadFailed
          ? 'File non caricato sul server'
          : analysisFailed
              ? 'File salvato, lettura automatica non riuscita'
              : 'Caricato adesso da te',
      badge: uploadFailed ? 'Non caricato' : 'Nuovo',
      detailSource: uploadFailed ? 'Solo su questo telefono' : 'Caricato da te',
      createdAt: _formatDate(now),
      attachmentId: attachmentId,
      timeline: [
        MedicalRecordTimelineEntry(label: 'Importato', value: _formatDate(now)),
        MedicalRecordTimelineEntry(
          label: 'Caricamento',
          value: uploadFailed ? 'Non riuscito' : 'Completato',
        ),
        const MedicalRecordTimelineEntry(label: "Pronto per l'invio", value: 'Disponibile'),
      ],
    );

    await _repository.saveRecord(record);
    if (bytes != null) {
      MedicalRecordFileCache.instance.put(
        id,
        bytes,
        picked.name,
        mimeType: attachmentMediaType(bytes, picked.name).toString(),
      );
    }

    if (!mounted) return;
    Navigator.of(context).pop(record);
  }

  bool _isUploadableFile(PlatformFile picked) {
    final extension = (picked.extension ?? '').toLowerCase();
    return _imageExtensions.contains(extension) || extension == 'pdf';
  }

  Future<_UploadFailedChoice> _askUploadFailed(String? reason) async {
    final choice = await showDialog<_UploadFailedChoice>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Il file non è stato caricato'),
        content: Text(
          '${reason ?? 'Controlla la connessione e riprova.'} '
          'In alternativa puoi salvare il referto solo su questo telefono: sarà marcato '
          'come «Non caricato» e non sarà disponibile sugli altri dispositivi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(_UploadFailedChoice.cancel),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(_UploadFailedChoice.saveLocalOnly),
            child: const Text('Salva solo sul telefono'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(_UploadFailedChoice.retry),
            child: const Text('Riprova'),
          ),
        ],
      ),
    );
    return choice ?? _UploadFailedChoice.cancel;
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final picked = _picked;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.text,
        title: const Text('Carica documento'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Per ${widget.petName} · PDF, JPG o PNG',
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: AppSpacing.xl),
              if (picked == null)
                _PickArea(onTap: _pickFile)
              else
                _PickedFileCard(file: picked, onChangeFile: _pickFile),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: picked == null || _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: PetLoader.small(color: AppColors.onPrimary),
                        )
                      : const Text('Carica'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickArea extends StatelessWidget {
  const _PickArea({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.xl),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.xxxl),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.xl),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(AppRadii.large),
                ),
                child: const Icon(Icons.upload_file_outlined, size: 26, color: AppColors.primary),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Tocca per scegliere un file', style: AppTextStyles.title.copyWith(fontSize: 16)),
              const SizedBox(height: AppSpacing.xs),
              Text('PDF, JPG o PNG dal tuo dispositivo', style: AppTextStyles.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickedFileCard extends StatelessWidget {
  const _PickedFileCard({required this.file, required this.onChangeFile});

  final PlatformFile file;
  final VoidCallback onChangeFile;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(AppRadii.medium),
            ),
            child: const Icon(Icons.description_outlined, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_extensionLabel(file.extension)} · ${_formatSize(file.size)}',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          TextButton(onPressed: onChangeFile, child: const Text('Cambia')),
        ],
      ),
    );
  }
}

String _extensionLabel(String? extension) =>
    (extension ?? '').toUpperCase().isEmpty ? 'FILE' : extension!.toUpperCase();

String _formatSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(0)} KB';
  return '${(kb / 1024).toStringAsFixed(1)} MB';
}

String _formatDate(DateTime date) {
  const months = [
    'Gen', 'Feb', 'Mar', 'Apr', 'Mag', 'Giu',
    'Lug', 'Ago', 'Set', 'Ott', 'Nov', 'Dic',
  ];
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '${date.day} ${months[date.month - 1]} ${date.year}, $hour:$minute';
}

enum _UploadFailedChoice { retry, saveLocalOnly, cancel }
