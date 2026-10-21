import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/date_formats.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/files/attachment_media_type.dart';
import '../../../../shared/formatters/date_input_formatter.dart';
import '../../../../shared/widgets/pet_loader.dart';
import '../../../../shared/widgets/typed_date_field.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../chat/data/chat_attachment_remote_data_source.dart';
import '../../../pets/data/pet_demo_store.dart';
import '../../data/medical_record_file_cache.dart';
import '../../data/medical_records_repository.dart';
import '../../domain/record_category.dart';
import '../record_category_labels.dart';

/// Adds an entry to a pet's cartella clinica, or edits the details of one.
///
/// New entry: the owner picks the category (preset by the tile it came
/// from), the type from a short list, the date of the event and a note, and
/// optionally a file. Images (jpg/jpeg/png) and PDFs are uploaded for real
/// via the existing chat-attachments pipeline (same Supabase Storage
/// bucket/backend route as chat photos — see
/// HttpChatAttachmentRemoteDataSource), so they survive a reload; the
/// text read from them is what the chat can use (with the pet's consent).
/// A PDF that cannot be uploaded still lives in [MedicalRecordFileCache]
/// for this session (enough for "Invia" right after uploading it).
///
/// With [existing] the page edits that entry's title, category, type, date
/// and notes; its file is left alone.
class MedicalRecordUploadPage extends StatefulWidget {
  const MedicalRecordUploadPage({
    super.key,
    required this.petName,
    this.initialCategory = RecordCategory.document,
    this.existing,
  });

  final String petName;
  final RecordCategory initialCategory;
  final MedicalRecordEntry? existing;

  @override
  State<MedicalRecordUploadPage> createState() =>
      _MedicalRecordUploadPageState();
}

class _MedicalRecordUploadPageState extends State<MedicalRecordUploadPage> {
  final _repository = MedicalRecordsRepository();
  final _attachmentDataSource = HttpChatAttachmentRemoteDataSource();
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _dateController = TextEditingController();
  final _notesController = TextEditingController();
  PlatformFile? _picked;
  bool _saving = false;

  late RecordCategory _category =
      widget.existing?.category ?? widget.initialCategory;
  late String? _subtype = widget.existing?.subtype;

  /// The categories that make sense for this animal (no vaccines for a fish),
  /// plus the one already chosen, so editing an old entry never drops its category.
  List<RecordCategory> get _offeredCategories {
    final pet = PetDemoStore.instance.byName(widget.petName);
    return [
      for (final category in RecordCategory.values)
        if (category == _category || category.isOfferedFor(pet?.species, breed: pet?.breed))
          category,
    ];
  }

  /// True once the owner typed in the title: from then on the file name no
  /// longer overwrites it.
  bool _titleEdited = false;
  bool _suggestionDismissed = false;

  bool get _editing => widget.existing != null;

  static const _imageExtensions = {'jpg', 'jpeg', 'png', 'webp'};

  // Backend rejections of the file itself: retrying or saving locally would
  // only hide the reason, so these stop the save with their message.
  static const _validationCodes = {
    'attachment_too_large',
    'unsupported_attachment_type',
    'pdf_too_many_pages',
    'pdf_unreadable',
  };

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _titleController.text = existing.title;
      _notesController.text = existing.notes;
      _titleEdited = true;
    }
    _dateController.text = formatDateForInput(
      existing?.eventDate ?? DateTime.now(),
    );
    _titleController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _dateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (!_titleEdited) _titleController.text = file.name;
    setState(() => _picked = file);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: parseStrictDate(_dateController.text) ?? now,
      firstDate: DateTime(1990),
      lastDate: now.add(const Duration(days: 365)),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (picked != null) {
      setState(() => _dateController.text = formatDateForInput(picked));
    }
  }

  String? _validateDate(String? value) =>
      parseStrictDate(value ?? '') == null ? context.l10n.medDateInvalid : null;

  bool get _canSave =>
      !_saving && (_picked != null || _titleController.text.trim().isNotEmpty);

  String get _titleOrFileName {
    final typed = _titleController.text.trim();
    return typed.isNotEmpty ? typed : (_picked?.name ?? '');
  }

  Future<void> _save() async {
    if (!_canSave) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_editing) {
      await _saveEdit();
      return;
    }

    final picked = _picked;
    final bytes = picked?.bytes;
    if (picked != null && bytes != null) {
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
    if (picked != null && bytes != null && _isUploadableFile(picked)) {
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
          await _persistRecord(
            attachmentId: null,
            uploadFailed: true,
            analysisFailed: false,
          );
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

  Future<void> _saveEdit() async {
    final existing = widget.existing!;
    setState(() => _saving = true);
    final updated = existing.copyWith(
      title: _titleOrFileName,
      category: _category,
      subtype: _subtype,
      clearSubtype: _subtype == null,
      eventDate: parseStrictDate(_dateController.text),
      notes: _notesController.text.trim(),
    );
    try {
      await _repository.updateRecordDetails(updated);
    } on MedicalRecordSaveException catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage(error.message);
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(updated);
  }

  Future<void> _persistRecord({
    required String? attachmentId,
    required bool uploadFailed,
    required bool analysisFailed,
  }) async {
    final picked = _picked;
    setState(() => _saving = true);

    final l10n = context.l10n;
    final now = DateTime.now();
    final id = 'upload-${now.microsecondsSinceEpoch}';
    final bytes = picked?.bytes;

    final record = MedicalRecordEntry(
      id: id,
      petName: widget.petName,
      title: _titleOrFileName,
      subtitle: picked == null
          ? ''
          : '${_extensionLabel(picked.extension)} · ${_formatSize(picked.size)}',
      // These texts are stored with the record, so they are written in the
      // language the owner is using at upload time.
      meta: picked == null
          ? ''
          : uploadFailed
          ? l10n.medicalRecordMetaNotUploaded
          : analysisFailed
          ? l10n.medicalRecordMetaAnalysisFailed
          : l10n.medicalRecordMetaUploadedNow,
      badge: picked == null
          ? ''
          : uploadFailed
          ? l10n.medicalRecordBadgeNotUploaded
          : l10n.medicalRecordBadgeNew,
      detailSource: picked == null
          ? ''
          : uploadFailed
          ? l10n.medicalRecordSourceLocalOnly
          : l10n.medicalRecordSourceUploadedByYou,
      createdAt: _formatDate(now),
      attachmentId: attachmentId,
      category: _category,
      subtype: _subtype,
      eventDate: parseStrictDate(_dateController.text),
      notes: _notesController.text.trim(),
      createdOn: now,
      timeline: [
        MedicalRecordTimelineEntry(
          label: l10n.medicalTimelineImported,
          value: _formatDate(now),
        ),
        MedicalRecordTimelineEntry(
          label: l10n.medicalTimelineUpload,
          value: uploadFailed
              ? l10n.medicalTimelineFailed
              : l10n.medicalTimelineCompleted,
        ),
        MedicalRecordTimelineEntry(
          label: l10n.medicalTimelineReadyToSend,
          value: l10n.medicalTimelineAvailable,
        ),
      ],
    );

    try {
      await _repository.saveRecord(record);
    } on MedicalRecordSaveException catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage(error.message);
      return;
    }
    if (picked != null && bytes != null) {
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
        title: Text(dialogContext.l10n.medicalUploadFailedTitle),
        content: Text(
          dialogContext.l10n.medicalUploadFailedBody(
            reason ?? dialogContext.l10n.medicalUploadFailedDefaultReason,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_UploadFailedChoice.cancel),
            child: Text(dialogContext.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(
              dialogContext,
            ).pop(_UploadFailedChoice.saveLocalOnly),
            child: Text(dialogContext.l10n.medicalUploadSaveLocalOnly),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_UploadFailedChoice.retry),
            child: Text(dialogContext.l10n.commonRetry),
          ),
        ],
      ),
    );
    return choice ?? _UploadFailedChoice.cancel;
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _selectCategory(RecordCategory category) {
    setState(() {
      _category = category;
      if (!category.subtypes.contains(_subtype)) _subtype = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final picked = _picked;
    final suggestion =
        _category == RecordCategory.document && !_suggestionDismissed
        ? suggestCategoryFromTitle(_titleController.text)
        : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.text,
        title: Text(
          _editing ? l10n.medEditDetailsTitle : _category.newEntryTitle(l10n),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.medicalUploadForPet(widget.petName),
                        style: AppTextStyles.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _FieldLabel(l10n.medFieldCategory),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          for (final category in _offeredCategories)
                            ChoiceChip(
                              label: Text(category.singularLabel(l10n)),
                              selected: _category == category,
                              onSelected: (_) => _selectCategory(category),
                              labelStyle: TextStyle(
                                color: _category == category
                                    ? AppColors.onPrimary
                                    : AppColors.secondaryText,
                                fontWeight: FontWeight.w700,
                              ),
                              selectedColor: AppColors.primary,
                              backgroundColor: AppColors.surface,
                              side: const BorderSide(color: AppColors.border),
                              showCheckmark: false,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadii.pill,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (_category.subtypes.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.lg),
                        _FieldLabel(l10n.medFieldType),
                        DropdownButtonFormField<String?>(
                          initialValue: _subtype,
                          isExpanded: true,
                          decoration: _decoration(),
                          items: [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Text(l10n.medFieldTypeNone),
                            ),
                            for (final key in _category.subtypes)
                              DropdownMenuItem<String?>(
                                value: key,
                                child: Text(recordSubtypeLabel(l10n, key)),
                              ),
                          ],
                          onChanged: (value) =>
                              setState(() => _subtype = value),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      _FieldLabel(l10n.medFieldTitle),
                      TextField(
                        controller: _titleController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: _decoration(),
                        onChanged: (_) => _titleEdited = true,
                      ),
                      if (suggestion != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        _SuggestionBanner(
                          text: l10n.medSuggestHint(
                            suggestion.singularLabel(l10n),
                          ),
                          applyLabel: l10n.medSuggestApply,
                          onApply: () => _selectCategory(suggestion),
                          onDismiss: () =>
                              setState(() => _suggestionDismissed = true),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      _FieldLabel(l10n.medFieldEventDate),
                      TypedDateField(
                        controller: _dateController,
                        validator: _validateDate,
                        onPick: _pickDate,
                        pickIcon: const Icon(
                          Icons.calendar_today_outlined,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.text,
                        ),
                        decoration: _decoration(hint: l10n.medDatePlaceholder),
                      ),
                      if (!_editing) ...[
                        const SizedBox(height: AppSpacing.lg),
                        _FieldLabel(l10n.medFieldFile),
                        if (picked == null)
                          _PickArea(onTap: _pickFile)
                        else
                          _PickedFileCard(
                            file: picked,
                            onChangeFile: _pickFile,
                          ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      _FieldLabel(l10n.medFieldNotes),
                      TextField(
                        controller: _notesController,
                        minLines: 3,
                        maxLines: 6,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: _decoration(hint: l10n.medFieldNotesHint),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _canSave ? _save : null,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: PetLoader.small(color: AppColors.onPrimary),
                        )
                      : Text(
                          _editing ? l10n.commonSave : l10n.medicalUploadAction,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

InputDecoration _decoration({String? hint}) {
  OutlineInputBorder border() => OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadii.medium),
    borderSide: const BorderSide(color: AppColors.border),
  );
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: AppColors.surface,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    ),
    border: border(),
    enabledBorder: border(),
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(text, style: AppTextStyles.caption),
    );
  }
}

/// "Looks like an exam — file it as one?": a proposal from the title, never
/// applied without the owner's tap.
class _SuggestionBanner extends StatelessWidget {
  const _SuggestionBanner({
    required this.text,
    required this.applyLabel,
    required this.onApply,
    required this.onDismiss,
  });

  final String text;
  final String applyLabel;
  final VoidCallback onApply;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.xs,
        AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(AppRadii.medium),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.lightbulb_outline_rounded,
            size: 18,
            color: AppColors.primary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: AppTextStyles.caption)),
          TextButton(onPressed: onApply, child: Text(applyLabel)),
          IconButton(
            onPressed: onDismiss,
            icon: const Icon(Icons.close_rounded, size: 18),
            color: AppColors.mutedText,
            visualDensity: VisualDensity.compact,
          ),
        ],
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
        borderRadius: BorderRadius.circular(AppRadii.large),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.large),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(AppRadii.medium),
                ),
                child: const Icon(
                  Icons.upload_file_outlined,
                  size: 22,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.medicalUploadPickPrompt,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      context.l10n.medicalUploadPickHint,
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
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
        borderRadius: BorderRadius.circular(AppRadii.large),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(AppRadii.medium),
            ),
            child: const Icon(
              Icons.description_outlined,
              color: AppColors.primary,
            ),
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
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_extensionLabel(file.extension)} · ${_formatSize(file.size)}',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onChangeFile,
            child: Text(context.l10n.medicalUploadChange),
          ),
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
  final months = appShortMonths();
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '${date.day} ${months[date.month - 1]} ${date.year}, $hour:$minute';
}

enum _UploadFailedChoice { retry, saveLocalOnly, cancel }
