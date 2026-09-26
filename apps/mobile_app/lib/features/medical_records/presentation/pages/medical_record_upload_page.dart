import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../data/medical_record_file_cache.dart';
import '../../data/medical_records_repository.dart';

/// Real file-picker upload flow for a pet's cartella clinica: the user
/// picks an actual file from their device, we show its real name/size,
/// and save it as a new record. There's no backend file storage behind
/// this demo, so the raw bytes only live in [MedicalRecordFileCache] for
/// the rest of this session (enough for "Invia file" to share the real
/// file right after uploading it).
class MedicalRecordUploadPage extends StatefulWidget {
  const MedicalRecordUploadPage({super.key, required this.petName});

  final String petName;

  @override
  State<MedicalRecordUploadPage> createState() => _MedicalRecordUploadPageState();
}

class _MedicalRecordUploadPageState extends State<MedicalRecordUploadPage> {
  final _repository = MedicalRecordsRepository();
  PlatformFile? _picked;
  bool _saving = false;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() => _picked = result.files.single);
  }

  Future<void> _save() async {
    final picked = _picked;
    if (picked == null || _saving) return;

    setState(() => _saving = true);

    final now = DateTime.now();
    final id = 'upload-${now.microsecondsSinceEpoch}';
    final record = MedicalRecordEntry(
      id: id,
      petName: widget.petName,
      title: picked.name,
      subtitle: '${_extensionLabel(picked.extension)} · ${_formatSize(picked.size)}',
      meta: 'Caricato adesso da te',
      badge: 'Nuovo',
      detailSource: 'Caricato da te',
      createdAt: _formatDate(now),
      timeline: [
        MedicalRecordTimelineEntry(label: 'Importato', value: _formatDate(now)),
        const MedicalRecordTimelineEntry(label: 'Revisionato', value: 'In attesa'),
        const MedicalRecordTimelineEntry(label: "Pronto per l'invio", value: 'Disponibile'),
      ],
    );

    await _repository.saveRecord(record);
    final bytes = picked.bytes;
    if (bytes != null) {
      MedicalRecordFileCache.instance.put(id, bytes, picked.name);
    }

    if (!mounted) return;
    Navigator.of(context).pop(record);
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
            AppSpacing.xl,
            AppSpacing.md,
            AppSpacing.xl,
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
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary),
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
