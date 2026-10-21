import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';
import '../../domain/body_condition.dart';
import '../../domain/body_condition_guide.dart';
import 'body_condition_guide_dialog.dart';

/// The "Corporatura" field of the profile form and of the weighing sheet.
/// There is no list to pick from: it shows the level assessed so far (or that
/// there is none) and a button that opens the guide, where the level is chosen
/// after seeing how to assess it for this species.
class BodyConditionPicker extends StatelessWidget {
  const BodyConditionPicker({
    required this.kind,
    required this.petName,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final BodyConditionGuideKind kind;
  final String petName;
  final BodyCondition? value;
  final ValueChanged<BodyCondition?> onChanged;

  Future<void> _open(BuildContext context) async {
    final choice = await showBodyConditionGuide(
      context,
      kind: kind,
      petName: petName,
      current: value,
    );
    if (choice != null) onChanged(choice.condition);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final condition = value;
    return Container(
      key: const ValueKey('bcs-picker'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.medium),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.petsFormBodyConditionLabel, style: AppTextStyles.caption),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              if (condition != null)
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(right: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: condition.color,
                    shape: BoxShape.circle,
                  ),
                ),
              Expanded(
                child: Text(
                  condition == null
                      ? l10n.monitoringBcsNotAssessed
                      : '${condition.score}/5 · ${condition.label}',
                  key: const ValueKey('bcs-picker-value'),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: condition == null
                        ? AppColors.mutedText
                        : AppColors.text,
                    fontWeight:
                        condition == null ? FontWeight.w500 : FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            key: const ValueKey('bcs-picker-open'),
            onPressed: () => _open(context),
            icon: const Icon(Icons.straighten_rounded, size: 18),
            label: Text(
              condition == null
                  ? l10n.monitoringBcsAssess
                  : l10n.monitoringBcsReassess,
            ),
          ),
        ],
      ),
    );
  }
}
