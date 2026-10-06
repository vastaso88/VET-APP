import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../data/billing_demo_store.dart';
import '../../domain/billing_models.dart';

/// Check-marked list of what a plan includes. Placeholder lines (a
/// commercial choice not made yet) get a muted "help" icon and italic text
/// so they can't be mistaken for a real promise.
class PlanFeatureList extends StatelessWidget {
  const PlanFeatureList({super.key, required this.features});

  final List<PlanFeature> features;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final feature in features)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  feature.isPlaceholder ? Icons.help_outline_rounded : Icons.check_rounded,
                  size: 18,
                  color: feature.isPlaceholder ? AppColors.mutedText : AppColors.success,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    feature.label,
                    style: feature.isPlaceholder
                        ? AppTextStyles.bodySmall.copyWith(
                            color: AppColors.mutedText,
                            fontStyle: FontStyle.italic,
                          )
                        : AppTextStyles.bodySmall,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The baseline shared by every plan, shown once above the plan cards.
class IncludedInAllPlansCard extends StatelessWidget {
  const IncludedInAllPlansCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.large),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Incluso in tutti i piani', style: AppTextStyles.title.copyWith(fontSize: 16)),
          const SizedBox(height: AppSpacing.sm),
          const PlanFeatureList(features: BillingDemoStore.includedInAllPlans),
        ],
      ),
    );
  }
}
