import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/files/attachment_media_type.dart';
import '../../../../shared/formatters/date_input_formatter.dart';
import '../../../../shared/widgets/pet_loader.dart';
import '../../../../shared/widgets/typed_date_field.dart';
import '../../../chat/data/chat_attachment_remote_data_source.dart';
import '../../../pets/domain/pet_models.dart';
import '../../data/medical_records_repository.dart';
import '../../data/pet_conditions_repository.dart';
import '../../domain/pet_condition.dart';
import '../record_file_actions.dart';

/// Adds or edits one illness of a pet: name, when it started, ongoing or
/// resolved (and when it ended), the therapy, notes and an optional file
/// (a prescription, a report) uploaded like the referti.
class PetConditionFormPage extends StatefulWidget {
  const PetConditionFormPage({required this.pet, this.existing, super.key});

  final PetProfile pet;
  final PetConditionEntry? existing;

  @override
  State<PetConditionFormPage> createState() => _PetConditionFormPageState();
}

class _PetConditionFormPageState extends State<PetConditionFormPage> {
  final _repository = PetConditionsRepository();
  final _attachmentDataSource = HttpChatAttachmentRemoteDataSource();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _startedController = TextEditingController();
  final _endedController = TextEditingController();
  final _therapyController = TextEditingController();
  final _notesController = TextEditingController();

  bool _ongoing = true;
  bool _saving = false;
  PlatformFile? _pickedFile;

  /// The file already attached to the entry being edited, until it is
  /// replaced or removed.
  String? _attachmentId;
  String? _attachmentName;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _nameController.text = existing.name;
      final started = existing.startedOn;
      if (started != null) _startedController.text = formatDateForInput(started);
      final ended = existing.endedOn;
      if (ended != null) _endedController.text = formatDateForInput(ended);
      _therapyController.text = existing.therapy;
      _notesController.text = existing.notes;
      _ongoing = existing.ongoing;
      _attachmentId = existing.attachmentId;
      _attachmentName = existing.attachmentName;
    }
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _startedController.dispose();
    _endedController.dispose();
    _therapyController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: parseStrictDate(controller.text) ?? now,
      firstDate: DateTime(1990),
      lastDate: now.add(const Duration(days: 365)),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (picked != null) {
      setState(() => controller.text = formatDateForInput(picked));
    }
  }

  /// A date may be left empty; one that is typed has to be a real day.
  String? _validateOptionalDate(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty || parseStrictDate(raw) != null) return null;
    return context.l10n.medDateInvalid;
  }

  String? _validateEndDate(String? value) {
    final invalid = _validateOptionalDate(value);
    if (invalid != null) return invalid;
    final ended = parseStrictDate(value ?? '');
    final started = parseStrictDate(_startedController.text);
    if (ended != null && started != null && ended.isBefore(started)) {
      return context.l10n.medCondEndBeforeStart;
    }
    return null;
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() => _pickedFile = result.files.single);
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    var attachmentId = _attachmentId;
    var attachmentName = _attachmentName;
    final picked = _pickedFile;
    final bytes = picked?.bytes;
    if (picked != null && bytes != null) {
      final validationError = attachmentValidationError(bytes, picked.name);
      if (validationError != null) {
        setState(() => _saving = false);
        _showMessage(validationError);
        return;
      }
      final result = await _attachmentDataSource.upload(
        petId: widget.pet.id,
        imageBytes: bytes,
        fileName: picked.name,
      );
      String? failure;
      result.fold(
        onSuccess: (uploaded) {
          attachmentId = uploaded.id;
          attachmentName = picked.name;
        },
        onFailure: (error) => failure = error.message,
      );
      if (failure != null) {
        if (!mounted) return;
        setState(() => _saving = false);
        _showMessage(failure!.isEmpty ? context.l10n.medCondUploadFailed : failure!);
        return;
      }
    }

    final condition = PetConditionEntry(
      id: widget.existing?.id ?? 'condition-${DateTime.now().microsecondsSinceEpoch}',
      petId: widget.pet.id,
      name: _nameController.text.trim(),
      startedOn: parseStrictDate(_startedController.text.trim()),
      ongoing: _ongoing,
      endedOn: _ongoing ? null : parseStrictDate(_endedController.text.trim()),
      therapy: _therapyController.text.trim(),
      notes: _notesController.text.trim(),
      attachmentId: attachmentId,
      attachmentName: attachmentName,
    );
    try {
      await _repository.save(condition);
    } on MedicalRecordSaveException catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage(error.message);
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.medCondDeleteTitle),
        content: Text(l10n.medCondDeleteBody(existing.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repository.delete(existing.id);
    } on MedicalRecordSaveException catch (error) {
      if (mounted) _showMessage(error.message);
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _openAttachment() {
    final id = _attachmentId;
    if (id == null) return;
    final name = _attachmentName ?? _nameController.text;
    openRecordFile(
      context,
      MedicalRecordEntry(
        id: widget.existing?.id ?? id,
        petName: widget.pet.name,
        title: name,
        subtitle: '',
        meta: '',
        badge: '',
        detailSource: '',
        createdAt: '',
        timeline: const [],
        attachmentId: id,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fileName = _pickedFile?.name ?? _attachmentName;
    final hasFile = _pickedFile != null || _attachmentId != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.text,
        title: Text(_editing ? l10n.medCatCondition : l10n.medNewCondition),
        actions: [
          if (_editing)
            IconButton(
              tooltip: l10n.commonDelete,
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
            ),
        ],
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
                        widget.pet.name,
                        style: AppTextStyles.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _Label(l10n.medCondName),
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: _decoration(),
                        validator: (value) => (value ?? '').trim().isEmpty
                            ? l10n.medCondNameRequired
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _Label(l10n.medCondStarted),
                      _DateField(
                        controller: _startedController,
                        validator: _validateOptionalDate,
                        onPick: () => _pickDate(_startedController),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _Label(l10n.medCondStatus),
                      Wrap(
                        spacing: AppSpacing.sm,
                        children: [
                          _StatusChip(
                            label: l10n.medCondOngoing,
                            selected: _ongoing,
                            onTap: () => setState(() => _ongoing = true),
                          ),
                          _StatusChip(
                            label: l10n.medCondResolved,
                            selected: !_ongoing,
                            onTap: () => setState(() => _ongoing = false),
                          ),
                        ],
                      ),
                      if (!_ongoing) ...[
                        const SizedBox(height: AppSpacing.lg),
                        _Label(l10n.medCondEnded),
                        _DateField(
                          controller: _endedController,
                          validator: _validateEndDate,
                          onPick: () => _pickDate(_endedController),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      _Label(l10n.medCondTherapy),
                      TextField(
                        controller: _therapyController,
                        minLines: 2,
                        maxLines: 5,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: _decoration(hint: l10n.medCondTherapyHint),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _Label(l10n.medCondAttachment),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadii.large),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.attach_file_rounded,
                              color: AppColors.secondaryStrong,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                fileName ?? l10n.medFieldTypeNone,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.text,
                                ),
                              ),
                            ),
                            if (_pickedFile == null && _attachmentId != null)
                              TextButton(
                                onPressed: _openAttachment,
                                child: Text(l10n.medCondOpenFile),
                              ),
                            TextButton(
                              onPressed: _pickFile,
                              child: Text(
                                hasFile ? l10n.medAttachChange : l10n.medAttachAdd,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _Label(l10n.medFieldNotes),
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
                  onPressed: _saving || _nameController.text.trim().isEmpty
                      ? null
                      : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: PetLoader.small(color: AppColors.onPrimary),
                        )
                      : Text(l10n.commonSave),
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

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(text, style: AppTextStyles.caption),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.controller,
    required this.validator,
    required this.onPick,
  });

  final TextEditingController controller;
  final FormFieldValidator<String> validator;
  final Future<void> Function() onPick;

  @override
  Widget build(BuildContext context) {
    return TypedDateField(
      controller: controller,
      validator: validator,
      onPick: onPick,
      pickIcon: const Icon(
        Icons.calendar_today_outlined,
        size: 18,
        color: AppColors.secondaryStrong,
      ),
      style: AppTextStyles.bodySmall.copyWith(color: AppColors.text),
      decoration: _decoration(hint: context.l10n.medDatePlaceholder),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      labelStyle: TextStyle(
        color: selected ? AppColors.onPrimary : AppColors.secondaryText,
        fontWeight: FontWeight.w700,
      ),
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surface,
      side: const BorderSide(color: AppColors.border),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
    );
  }
}
