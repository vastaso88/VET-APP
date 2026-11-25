import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../shared/widgets/app_card.dart';

class PetSection extends StatelessWidget {
  const PetSection({
    required this.title,
    required this.children,
    super.key,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.title),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(subtitle!, style: AppTextStyles.bodySmall),
          ],
          const SizedBox(height: AppSpacing.lg),
          ...children,
        ],
      ),
    );
  }
}

class PetInfoRow extends StatelessWidget {
  const PetInfoRow({
    required this.label,
    required this.value,
    super.key,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final labelText = Text(
      label,
      style: AppTextStyles.caption.copyWith(
        color: AppColors.mutedText,
        fontWeight: FontWeight.w700,
      ),
    );
    final valueText = Text(
      value,
      style: AppTextStyles.bodySmall.copyWith(color: AppColors.text),
    );
    // Large text: one under the other, the words stay whole.
    final stacked = MediaQuery.textScalerOf(context).scale(14) > 20;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [labelText, valueText],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 120, child: labelText),
                Expanded(child: valueText),
              ],
            ),
    );
  }
}
