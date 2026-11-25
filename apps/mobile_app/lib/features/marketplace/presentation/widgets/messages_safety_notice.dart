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
  Widget build(BuildContext context) => _WarningBox(
        key: const ValueKey('marketplace-messages-safety-notice'),
        icon: Icons.shield_outlined,
        text: context.l10n.marketplaceMessagesSafetyNotice,
      );
}

/// Next to a text with a contact or a code, written or received. A reminder: the
/// message goes as any other.
class MessageCautionNotice extends StatelessWidget {
  const MessageCautionNotice({super.key});

  @override
  Widget build(BuildContext context) => _WarningBox(
        icon: Icons.info_outline,
        text: context.l10n.marketplaceMessagesCaution,
      );
}

class _WarningBox extends StatelessWidget {
  const _WarningBox({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: BorderRadius.circular(AppRadii.large),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.warningStrong, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.warningStrong),
            ),
          ),
        ],
      ),
    );
  }
}
