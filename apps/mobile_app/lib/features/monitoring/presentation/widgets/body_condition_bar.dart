import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../domain/body_condition.dart';

const _segmentGap = 3.0;

/// The five body condition levels as one bar. Every level carries its number and
/// the ends their name: the colour only adds to them. The owner's level is full
/// colour, outlined and bold (the page writes its name, "3/5 · Normale"). With
/// [onSelected] each level is a button (the guide popup).
class BodyConditionBar extends StatelessWidget {
  const BodyConditionBar({this.selected, this.onSelected, super.key});

  final BodyCondition? selected;
  final ValueChanged<BodyCondition>? onSelected;

  @override
  Widget build(BuildContext context) {
    final endStyle = AppTextStyles.caption.copyWith(fontWeight: FontWeight.w500);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (final condition in BodyCondition.values)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: condition == BodyCondition.values.last ? 0 : _segmentGap,
                  ),
                  child: _Level(
                    condition: condition,
                    selected: selected,
                    onTap: onSelected == null ? null : () => onSelected!(condition),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(BodyCondition.values.first.label, style: endStyle)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                BodyCondition.values.last.label,
                textAlign: TextAlign.end,
                style: endStyle,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Level extends StatelessWidget {
  const _Level({required this.condition, required this.selected, required this.onTap});

  final BodyCondition condition;
  final BodyCondition? selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final chosen = selected == condition;
    final segment = Container(
      key: ValueKey('bcs-segment-${condition.score}'),
      constraints: const BoxConstraints(minHeight: 36),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: condition.color.withValues(
          alpha: chosen ? 1 : (selected == null ? 0.45 : 0.25),
        ),
        borderRadius: BorderRadius.circular(8),
        border: chosen ? Border.all(color: AppColors.text, width: 2) : null,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        // The number always on a light ground, whatever the colour around it.
        decoration: BoxDecoration(
          color: chosen ? AppColors.surfaceElevated : null,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '${condition.score}',
          key: ValueKey('bcs-label-${condition.score}'),
          maxLines: 1,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.text,
            fontWeight: chosen ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ),
    );
    // Spoken as the page writes it, with its name.
    return Semantics(
      button: onTap != null,
      selected: chosen,
      label: '${condition.score}/5 · ${condition.label}',
      excludeSemantics: true,
      onTap: onTap,
      child: onTap == null
          ? segment
          : InkWell(
              key: ValueKey('bcs-level-${condition.score}'),
              borderRadius: BorderRadius.circular(8),
              onTap: onTap,
              // 48 px to touch.
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: segment,
              ),
            ),
    );
  }
}
