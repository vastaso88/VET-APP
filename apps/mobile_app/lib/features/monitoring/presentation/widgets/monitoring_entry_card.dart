import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';
import '../../../dog_walks/domain/walk_eligibility.dart';
import '../../../pets/domain/pet_models.dart';
import '../../domain/weight_measurement.dart';
import '../pages/monitoring_page.dart';

/// The row of the pet's records tab that opens "Monitoraggio". Nothing for a
/// species without weight monitoring (fish).
class MonitoringEntryCard extends StatelessWidget {
  const MonitoringEntryCard({required this.pet, super.key});

  final PetProfile pet;

  @override
  Widget build(BuildContext context) {
    if (!supportsWeightMonitoring(pet)) return const SizedBox.shrink();
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.large),
        child: InkWell(
          key: const ValueKey('monitoring-entry'),
          borderRadius: BorderRadius.circular(AppRadii.large),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => MonitoringPage(pet: pet)),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.large),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.accentSoft,
                    borderRadius: BorderRadius.circular(AppRadii.medium),
                  ),
                  child: const Icon(Icons.show_chart_rounded,
                      color: AppColors.primary),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.monitoringTitle,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        isDogSpecies(pet.species)
                            ? l10n.monitoringEntrySubtitleWithActivity
                            : l10n.monitoringEntrySubtitleWeight,
                        style: AppTextStyles.caption
                            .copyWith(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.mutedText),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
