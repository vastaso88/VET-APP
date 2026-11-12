import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';
import '../../../medical_records/presentation/record_category_labels.dart';
import '../../domain/reminder_category.dart';
import '../reminder_category_labels.dart';

/// The category of a reminder as chips - each with the symbol of its record
/// category - and, for the clinical ones that have them, the finer types.
/// Shared by the reminder form and the "Fatto?" sheet so both read the same.
class ReminderCategoryPicker extends StatelessWidget {
  const ReminderCategoryPicker({
    required this.offered,
    required this.category,
    required this.subtype,
    required this.onCategory,
    required this.onSubtype,
    this.showSubtypes = true,
    super.key,
  });

  /// Only the categories that make sense for the animal (no vaccines for fish).
  final List<ReminderCategory> offered;
  final ReminderCategory category;
  final String? subtype;
  final ValueChanged<ReminderCategory> onCategory;
  final ValueChanged<String?> onSubtype;
  final bool showSubtypes;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.remindersFormCategory, style: AppTextStyles.caption),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final option in offered)
              _Choice(
                icon: option.icon,
                label: option.label(l10n),
                selected: category == option,
                onSelected: () => onCategory(option),
              ),
          ],
        ),
        if (showSubtypes && category.subtypes.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(l10n.remindersFormSubtype, style: AppTextStyles.caption),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final option in category.subtypes)
                _Choice(
                  label: recordSubtypeLabel(l10n, option),
                  selected: subtype == option,
                  onSelected: () => onSubtype(subtype == option ? null : option),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      avatar: icon == null
          ? null
          : Icon(icon, size: 16, color: selected ? AppColors.onPrimary : AppColors.secondaryText),
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      labelStyle: TextStyle(
        color: selected ? AppColors.onPrimary : AppColors.secondaryText,
        fontWeight: FontWeight.w700,
      ),
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surface,
      side: const BorderSide(color: AppColors.border),
      showCheckmark: false,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.pill)),
    );
  }
}
