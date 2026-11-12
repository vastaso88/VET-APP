import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';

/// Shown to an owner without a plan, who sees only the first look of each ad:
/// says what a plan adds and offers the way back to the plans.
class LimitedMarketplaceNotice extends StatelessWidget {
  const LimitedMarketplaceNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('marketplace-limited-notice'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.large),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lock_outline_rounded,
                  color: AppColors.info, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  context.l10n.marketplaceLimitedNotice,
                  style:
                      AppTextStyles.bodySmall.copyWith(color: AppColors.info),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: Text(context.l10n.marketplaceLimitedSeePlans),
            ),
          ),
        ],
      ),
    );
  }
}
