import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../domain/body_condition.dart';

/// The five body condition levels as one coloured bar: the owner's level is
/// full colour and bold, the others are faded. With [onSelected] each level
/// is a button (the guide popup).
class BodyConditionBar extends StatelessWidget {
  const BodyConditionBar({this.selected, this.onSelected, super.key});

  final BodyCondition? selected;
  final ValueChanged<BodyCondition>? onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final condition in BodyCondition.values)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: condition == BodyCondition.values.last ? 0 : 3,
              ),
              child: InkWell(
                key: onSelected == null
                    ? null
                    : ValueKey('bcs-level-${condition.score}'),
                borderRadius: BorderRadius.circular(6),
                onTap: onSelected == null ? null : () => onSelected!(condition),
                child: Column(
                  children: [
                    Container(
                      key: ValueKey('bcs-segment-${condition.score}'),
                      height: 8,
                      decoration: BoxDecoration(
                        color: selected == null || selected == condition
                            ? condition.color.withValues(
                                alpha: selected == null ? 0.45 : 1,
                              )
                            : condition.color.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        condition.label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 10,
                          color: selected == condition
                              ? AppColors.text
                              : AppColors.mutedText,
                          fontWeight: selected == condition
                              ? FontWeight.w800
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
