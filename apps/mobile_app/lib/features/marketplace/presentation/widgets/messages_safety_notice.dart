import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';

/// Always at the start of a conversation, also before the first message: contacts
/// written in a message are not forbidden, so the warning has to be there.
class MessagesSafetyNotice extends StatelessWidget {
  const MessagesSafetyNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('marketplace-messages-safety-notice'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: BorderRadius.circular(AppRadii.large),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined, color: AppColors.warningStrong, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              context.l10n.marketplaceMessagesSafetyNotice,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.warningStrong),
            ),
          ),
        ],
      ),
    );
  }
}
