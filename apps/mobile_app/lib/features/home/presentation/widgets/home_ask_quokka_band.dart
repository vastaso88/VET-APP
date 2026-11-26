import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/pet_loader.dart';
import '../../../../shared/widgets/quokka_logo.dart';

/// "Chiedi a Quokka": the way from Home into a new chat.
class HomeAskQuokkaBand extends StatelessWidget {
  const HomeAskQuokkaBand({
    super.key,
    required this.subtitle,
    required this.onTap,
    this.opening = false,
  });

  final String subtitle;
  final VoidCallback onTap;

  /// The chat is being opened: the arrow gives way to the small loader.
  final bool opening;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: Material(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(AppRadii.large),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const ValueKey('home-ask-quokka'),
            onTap: opening ? null : onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 80),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: Row(
                  children: [
                    const QuokkaHeadRound(),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.homeAskQuokka,
                            style: AppTextStyles.title.copyWith(
                              fontSize: 18,
                              height: 1.25,
                              color: AppColors.onPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodySmall.copyWith(
                              fontSize: 13,
                              color: AppColors.onPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    if (opening)
                      PetLoader.small(color: AppColors.onPrimary)
                    else
                      Icon(Icons.chevron_right_rounded, color: AppColors.onPrimary),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
