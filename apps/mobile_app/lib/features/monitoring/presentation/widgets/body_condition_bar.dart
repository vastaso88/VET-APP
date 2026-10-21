import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../domain/body_condition.dart';

/// Base and smallest size of the level labels, in logical pixels before the
/// text scaler is applied.
const bodyConditionLabelMaxSize = 11.0;
const bodyConditionLabelMinSize = 8.0;
const _segmentGap = 3.0;

/// The largest size, not above [bodyConditionLabelMaxSize], at which the
/// longest word of every label still fits a column of [columnWidth]. One size
/// for all labels, so none of them looks smaller than the others; a long label
/// breaks onto a second line instead of shrinking.
double bodyConditionLabelSize({
  required List<String> labels,
  required double columnWidth,
  required TextScaler textScaler,
  TextDirection textDirection = TextDirection.ltr,
}) {
  final words = [
    for (final label in labels) ...label.split(RegExp(r'\s+')).where((w) => w.isNotEmpty),
  ];

  bool fits(double size) {
    for (final word in words) {
      final painter = TextPainter(
        text: TextSpan(
          text: word,
          // Bold is the widest weight a label gets (the selected level).
          style: AppTextStyles.caption.copyWith(fontSize: size, fontWeight: FontWeight.w800),
        ),
        textDirection: textDirection,
        textScaler: textScaler,
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      if (width > columnWidth) return false;
    }
    return true;
  }

  var size = bodyConditionLabelMaxSize;
  while (size > bodyConditionLabelMinSize && !fits(size)) {
    size -= 0.25;
  }
  return math.max(size, bodyConditionLabelMinSize);
}

/// The five body condition levels as one coloured bar: the owner's level is
/// full colour and bold, the others are faded. With [onSelected] each level
/// is a button (the guide popup).
class BodyConditionBar extends StatelessWidget {
  const BodyConditionBar({this.selected, this.onSelected, super.key});

  final BodyCondition? selected;
  final ValueChanged<BodyCondition>? onSelected;

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = BodyCondition.values.length;
        final columnWidth = (constraints.maxWidth - _segmentGap * (count - 1)) / count;
        final labelSize = bodyConditionLabelSize(
          labels: [for (final c in BodyCondition.values) c.label],
          columnWidth: columnWidth,
          textScaler: textScaler,
        );
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final condition in BodyCondition.values)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: condition == BodyCondition.values.last ? 0 : _segmentGap,
                  ),
                  child: InkWell(
                    key: onSelected == null ? null : ValueKey('bcs-level-${condition.score}'),
                    borderRadius: BorderRadius.circular(6),
                    onTap: onSelected == null ? null : () => onSelected!(condition),
                    child: Column(
                      children: [
                        Container(
                          key: ValueKey('bcs-segment-${condition.score}'),
                          height: 8,
                          decoration: BoxDecoration(
                            color: selected == null || selected == condition
                                ? condition.color.withValues(alpha: selected == null ? 0.45 : 1)
                                : condition.color.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          condition.label,
                          key: ValueKey('bcs-label-${condition.score}'),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          softWrap: true,
                          overflow: TextOverflow.visible,
                          style: AppTextStyles.caption.copyWith(
                            fontSize: labelSize,
                            color: selected == condition ? AppColors.text : AppColors.mutedText,
                            fontWeight:
                                selected == condition ? FontWeight.w800 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
