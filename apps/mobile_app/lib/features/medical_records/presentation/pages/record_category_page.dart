import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/date_formats.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/files/attachment_media_type.dart';
import '../../../../shared/widgets/pet_loader.dart';
import '../../../pets/domain/pet_models.dart';
import '../../data/medical_records_repository.dart';
import '../../domain/record_category.dart';
import '../record_category_labels.dart';
import '../record_file_actions.dart';
import 'medical_record_upload_page.dart';

/// The entries of one category (e.g. all the visits) of a pet, newest event
/// first, with "Aggiungi" and the same actions as before on each entry: open,
/// send, rename, delete (plus editing its details). A long press selects
/// entries to send together.
class RecordCategoryPage extends StatefulWidget {
  const RecordCategoryPage({
    required this.pet,
    required this.category,
    required this.repository,
    super.key,
  });

  final PetProfile pet;
  final RecordCategory category;
  final MedicalRecordsRepository repository;

  @override
  State<RecordCategoryPage> createState() => _RecordCategoryPageState();
}

class _RecordCategoryPageState extends State<RecordCategoryPage> {
  late Future<List<MedicalRecordEntry>> _future = widget.repository
      .loadRecords();

  /// Entries picked for a group share. A non-empty set means selection mode:
  /// taps toggle instead of opening the actions sheet.
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    MedicalRecordsRepository.changes.addListener(_onRecordsChanged);
  }

  @override
  void dispose() {
    MedicalRecordsRepository.changes.removeListener(_onRecordsChanged);
    super.dispose();
  }

  void _onRecordsChanged() {
    if (!mounted) return;
    setState(() => _future = widget.repository.loadRecords());
  }

  Future<void> _reload() async {
    setState(() => _future = widget.repository.loadRecords());
    await _future;
  }

  Future<void> _add() async {
    await Navigator.of(context).push(
      MaterialPageRoute<MedicalRecordEntry>(
        builder: (_) => MedicalRecordUploadPage(
          petName: widget.pet.name,
          initialCategory: widget.category,
        ),
      ),
    );
    if (!mounted) return;
    await _reload();
  }

  void _onTap(MedicalRecordEntry record) {
    if (_selectedIds.isNotEmpty) {
      _toggleSelected(record);
      return;
    }
    showRecordActions(
      context,
      record: record,
      onChanged: () => unawaited(_reload()),
    );
  }

  void _toggleSelected(MedicalRecordEntry record) {
    setState(() {
      if (!_selectedIds.remove(record.id)) _selectedIds.add(record.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final category = widget.category;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.text,
        title: Text(category.tileLabel(l10n)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.medAddAction),
      ),
      body: SafeArea(
        child: FutureBuilder<List<MedicalRecordEntry>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: PetLoader());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
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
                        onPressed: () => unawaited(_reload()),
                        child: Text(l10n.commonRetry),
                      ),
                    ],
                  ),
                ),
              );
            }

            final records =
                (snapshot.data ?? const <MedicalRecordEntry>[])
                    .where(
                      (record) =>
                          record.petName == widget.pet.name &&
                          record.category == category,
                    )
                    .toList()
                  ..sort((a, b) => b.sortDate.compareTo(a.sortDate));

            if (records.isEmpty) {
              return _EmptyCategory(
                icon: category.icon,
                title: category.emptyTitle(l10n),
                body: category.emptyBody(l10n, widget.pet.name),
                actionLabel: category.emptyAction(l10n),
                onAction: _add,
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                96,
              ),
              children: [
                Text(
                  '${widget.pet.name} · ${l10n.medCatCount(records.length)}',
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: AppSpacing.md),
                if (_selectedIds.isNotEmpty) ...[
                  _SelectionBar(
                    count: _selectedIds.length,
                    onCancel: () => setState(_selectedIds.clear),
                    onSend: () => shareRecords(
                      context,
                      records
                          .where((r) => _selectedIds.contains(r.id))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                for (final record in records) ...[
                  _EntryRow(
                    record: record,
                    selected: _selectedIds.contains(record.id),
                    onTap: () => _onTap(record),
                    onLongPress: () => _toggleSelected(record),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.record,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  final MedicalRecordEntry record;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final subtype = record.subtype;
    final subtitle = [
      formatAppDate(record.sortDate, 'd MMM y'),
      if (subtype != null) recordSubtypeLabel(l10n, subtype),
    ].join(' · ');
    // Only a proposal, shown for a plain document whose title says more.
    final suggestion = record.category == RecordCategory.document
        ? suggestCategoryFromTitle(record.title)
        : null;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.large),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.large),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.large),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(AppRadii.medium),
                ),
                child: Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : isPdfFileName(record.title)
                      ? Icons.picture_as_pdf_outlined
                      : record.category.icon,
                  size: 17,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              if (suggestion != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accentSoft,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Text(
                    l10n.medSuggestPill(suggestion.singularLabel(l10n)),
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: AppSpacing.xs),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.mutedText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown while entries are selected for a group share.
class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.count,
    required this.onCancel,
    required this.onSend,
  });

  final int count;
  final VoidCallback onCancel;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(AppRadii.medium),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.l10n.petsDetailSelectedCount(count),
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: onCancel,
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton.icon(
            onPressed: onSend,
            icon: const Icon(Icons.ios_share_rounded, size: 18),
            label: Text(context.l10n.petsDetailRecordsSend),
          ),
        ],
      ),
    );
  }
}

class _EmptyCategory extends StatelessWidget {
  const _EmptyCategory({
    required this.icon,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.accentSoft,
                borderRadius: BorderRadius.circular(AppRadii.large),
              ),
              child: Icon(icon, size: 30, color: AppColors.primary),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.title,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              body,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
