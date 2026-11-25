import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../design_system/tokens/app_colors.dart';
import '../../../../../design_system/tokens/app_radii.dart';
import '../../../../../design_system/tokens/app_spacing.dart';
import '../../../../../design_system/tokens/app_text_styles.dart';
import '../../../../../l10n/l10n.dart';
import '../../data/reminders_repository.dart';
import '../../domain/reminder_presentation.dart';
import '../reminder_category_labels.dart';
import '../widgets/reminder_completion_sheet.dart';
import '../widgets/reminder_page_parts.dart';
import 'reminder_create_edit_pages.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../design_system/atoms/outline_icon_button.dart';

class ReminderDetailPage extends StatefulWidget {
  const ReminderDetailPage({super.key, this.reminder});

  final ReminderEntry? reminder;

  @override
  State<ReminderDetailPage> createState() => _ReminderDetailPageState();
}

class _ReminderDetailPageState extends State<ReminderDetailPage> {
  final _repository = RemindersRepository();
  late ReminderEntry? _reminder = widget.reminder;

  Future<void> _openEdit() async {
    final updated = await Navigator.of(context).push<ReminderEntry>(
      MaterialPageRoute<ReminderEntry>(
        builder: (_) => ReminderEditPage(reminder: _reminder),
      ),
    );
    if (updated != null && mounted) {
      setState(() => _reminder = updated);
    }
  }

  Future<void> _delete() async {
    final reminder = _reminder;
    if (reminder == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.large)),
        title: Text(dialogContext.l10n.remindersDeleteConfirmTitle),
        content: Text(dialogContext.l10n.remindersDeleteConfirmBody(reminder.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _repository.deleteReminder(reminder.id);
    } on ReminderSyncException catch (error) {
      if (mounted) showReminderFailure(error.message);
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final reminder = _reminder;

    if (reminder == null) {
      return ReminderPageShell(
        title: context.l10n.remindersNotFoundTitle,
        subtitle: context.l10n.remindersNotFoundSubtitle,
        child: EmptyState.icon(
          icon: Icons.search_off_rounded,
          title: context.l10n.remindersNotFoundPanelTitle,
          text: context.l10n.remindersNotFoundBody,
          padding: EdgeInsets.zero,
          action: FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.remindersBackToList),
          ),
        ),
      );
    }

    final presentation = ReminderPresentation.of(reminder);

    return ReminderPageShell(
      title: context.l10n.remindersDetailTitle,
      subtitle: context.l10n.remindersDetailSubtitle,
      actions: [
        OutlineIconButton(
          tooltip: context.l10n.commonEdit,
          onPressed: _openEdit,
          icon: Icons.edit_outlined,
        ),
      ],
      petName: reminder.petName,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SummaryCard(
            title: reminder.title,
            body: reminder.note.isEmpty
                ? context.l10n.remindersNoNote
                : reminder.note,
            icon: presentation.icon,
          ),
          const SizedBox(height: AppSpacing.lg),
          _FormPanel(
            title: context.l10n.remindersSummaryTitle,
            items: [
              _FormItem(
                  label: context.l10n.remindersSummaryPet,
                  value: reminder.petName.isEmpty ? '—' : reminder.petName),
              _FormItem(label: context.l10n.remindersFormKind, value: presentation.kindLabel),
              _FormItem(
                  label: context.l10n.remindersFormCategory,
                  value: reminder.effectiveCategory.label(context.l10n)),
              _FormItem(label: context.l10n.remindersSummaryStatus, value: presentation.dateLabel),
            ],
            onSave: _openEdit,
            onCancel: () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: AppSpacing.md),
          if (!reminder.isDone) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  final handled = await askToCompleteReminder(context, reminder);
                  if (handled && mounted) navigator.pop();
                },
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: Text(context.l10n.remindersDoneTitle),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline_rounded,
                  size: 18, color: AppColors.danger),
              label: Text(context.l10n.remindersDeleteButton,
                  style: const TextStyle(color: AppColors.danger)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.body,
    required this.icon,
  });

  final String title;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      width: double.infinity,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.secondarySoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: AppColors.secondaryStrong),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.title),
                const SizedBox(height: AppSpacing.sm),
                Text(body,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FormPanel extends StatelessWidget {
  const _FormPanel({
    required this.title,
    required this.items,
    required this.onSave,
    required this.onCancel,
  });

  final String title;
  final List<_FormItem> items;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.title),
          const SizedBox(height: AppSpacing.xl),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _ReadValue(label: item.label, value: item.value),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                    onPressed: onSave, child: Text(context.l10n.commonEdit)),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                  child: OutlinedButton(
                      onPressed: onCancel, child: Text(context.l10n.commonBack))),
            ],
          ),
        ],
      ),
    );
  }
}

class _FormItem {
  const _FormItem({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;
}

class _ReadValue extends StatelessWidget {
  const _ReadValue({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption),
        const SizedBox(height: 2),
        Text(value, style: AppTextStyles.body.copyWith(color: AppColors.text)),
      ],
    );
  }
}
