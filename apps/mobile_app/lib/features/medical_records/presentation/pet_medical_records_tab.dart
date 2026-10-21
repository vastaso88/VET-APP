import 'dart:async';

import 'package:flutter/material.dart';

import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radii.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_text_styles.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/pet_loader.dart';
import '../../pets/domain/pet_models.dart';
import '../../pets/presentation/widgets/medical_record_consent_card.dart';
import '../data/medical_records_repository.dart';
import '../domain/history_event.dart';
import '../domain/pet_condition.dart';
import '../domain/record_category.dart';
import 'history_export.dart';
import 'medical_records_controller.dart';
import 'pages/medical_record_upload_page.dart';
import 'pages/pet_condition_form_page.dart';
import 'pages/pet_conditions_page.dart';
import 'pages/record_category_page.dart';
import 'pet_history_section.dart';
import 'record_category_labels.dart';
import 'record_file_actions.dart';

/// The "Cartella clinica" tab of a pet: the consent switch for the chat, an
/// "Aggiungi" button and a grid with one tile per category (Visite, Esami,
/// Vaccini, Terapie, Documenti, Patologie), each with how many entries it
/// holds. A tile opens that category's list.
class PetMedicalRecordsTab extends StatefulWidget {
  const PetMedicalRecordsTab({
    required this.pet,
    required this.repository,
    super.key,
  });

  final PetProfile pet;
  final MedicalRecordsRepository repository;

  @override
  State<PetMedicalRecordsTab> createState() => _PetMedicalRecordsTabState();
}

class _PetMedicalRecordsTabState extends State<PetMedicalRecordsTab> {
  /// Records and illnesses, reloaded on every save/edit/delete anywhere in
  /// the app, so the tiles, the lists and the Storico never show old numbers.
  late final MedicalRecordsController _controller = MedicalRecordsController(
    repository: widget.repository,
    conditionsPetId: widget.pet.id,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _open(Widget page) {
    unawaited(
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page)),
    );
  }

  void _openCategory(RecordCategory category) => _open(
        RecordCategoryPage(
          pet: widget.pet,
          category: category,
          repository: widget.repository,
        ),
      );

  void _openConditions() => _open(PetConditionsPage(pet: widget.pet));

  // Saving, editing or deleting anything bumps the repositories' `changes`,
  // which the controller listens to: no reload is needed when coming back.
  Future<void> _addEntry(RecordCategory category) async {
    await Navigator.of(context).push(
      MaterialPageRoute<MedicalRecordEntry>(
        builder: (_) => MedicalRecordUploadPage(
          petName: widget.pet.name,
          initialCategory: category,
        ),
      ),
    );
  }

  void _openEvent(HistoryEvent event) {
    final record = event.record;
    if (record != null) {
      unawaited(
        showRecordActions(
          context,
          record: record,
          onChanged: () => unawaited(_controller.reload()),
        ),
      );
      return;
    }
    _open(PetConditionFormPage(pet: widget.pet, existing: event.condition));
  }

  List<MedicalRecordEntry> get _petRecords =>
      (_controller.records ?? const <MedicalRecordEntry>[])
          .where((record) => record.petName == widget.pet.name)
          .toList(growable: false);

  Future<void> _exportHistory() => exportPetHistory(
        context,
        pet: widget.pet,
        records: _petRecords,
        conditions: _controller.conditions,
      );

  Future<void> _addCondition() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PetConditionFormPage(pet: widget.pet),
      ),
    );
  }

  Future<void> _showAddSheet() async {
    final l10n = context.l10n;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Text(l10n.medAddTitle, style: AppTextStyles.title),
              ),
              for (final category in RecordCategory.values)
                ListTile(
                  leading: Icon(category.icon, color: AppColors.primary),
                  title: Text(category.singularLabel(l10n)),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    unawaited(_addEntry(category));
                  },
                ),
              ListTile(
                leading: const Icon(conditionIcon, color: AppColors.primary),
                title: Text(l10n.medCatCondition),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  unawaited(_addCondition());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showSendSheet(List<MedicalRecordEntry> records) async {
    final withFiles = records.where(recordHasFile).toList(growable: false);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sheetContext.l10n.petsDetailRecordsSendTitle,
                style: AppTextStyles.title,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                sheetContext.l10n.petsDetailRecordsSendSubtitle,
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.picture_as_pdf_outlined,
                  color: AppColors.primary,
                ),
                title: Text(sheetContext.l10n.medHistorySendAll),
                subtitle: Text(sheetContext.l10n.medHistorySendAllSubtitle),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  unawaited(_exportHistory());
                },
              ),
              if (withFiles.isNotEmpty) ...[
                const Divider(),
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Text(
                    sheetContext.l10n.medHistorySendFiles,
                    style: AppTextStyles.caption,
                  ),
                ),
              ],
              for (final record in withFiles)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    record.category.icon,
                    color: AppColors.primary,
                  ),
                  title: Text(
                    record.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    unawaited(shareRecords(context, [record]));
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final l10n = context.l10n;
    if (_controller.recordsFailed) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.petsDetailRecordsLoadError,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () => unawaited(_controller.retry()),
              child: Text(l10n.commonRetry),
            ),
          ],
        ),
      );
    }
    if (_controller.records == null) {
      return const Center(child: PetLoader());
    }

    final records = _petRecords;
    int countOf(RecordCategory category) =>
        records.where((record) => record.category == category).length;
    final conditions = _controller.conditions;
    final tiles = <Widget>[
      for (final category in RecordCategory.values)
        _CategoryTile(
          icon: category.icon,
          label: category.tileLabel(l10n),
          countText: l10n.medCatCount(countOf(category)),
          onTap: () => _openCategory(category),
        ),
      _CategoryTile(
        icon: conditionIcon,
        label: l10n.medCatCondition,
        countText:
            conditions == null ? '—' : l10n.medCatCount(conditions.length),
        onTap: _openConditions,
      ),
    ];

    // One scrollable list: the consent card, the actions and the tiles
    // scroll together, so nothing can overflow a fixed-height tab body.
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      children: [
        MedicalRecordConsentCard(pet: widget.pet),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _showAddSheet,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(l10n.medAddAction),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showSendSheet(records),
                icon: const Icon(Icons.ios_share_rounded, size: 18),
                label: Text(l10n.petsDetailRecordsSend),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        // Rows sized by their tallest tile (not a fixed ratio), so a
        // larger text size makes the tiles taller instead of overflowing.
        for (var i = 0; i < tiles.length; i += 2) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: tiles[i]),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: tiles[i + 1]),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        PetHistorySection(
          events: buildHistoryEvents(
            records: records,
            conditions: conditions ?? const <PetConditionEntry>[],
          ),
          onOpenEvent: _openEvent,
          onExport: _exportHistory,
        ),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.icon,
    required this.label,
    required this.countText,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String countText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.large),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.large),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.large),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(AppRadii.medium),
                ),
                child: Icon(icon, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      countText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
