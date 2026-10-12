import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_text_styles.dart';

enum AiDisclosureLevel {
  aiGenerated,
  notHumanReviewed,
}

class AiDisclosureBadge extends StatelessWidget {
  const AiDisclosureBadge({
    super.key,
    this.level = AiDisclosureLevel.aiGenerated,
  });

  final AiDisclosureLevel level;

  String _label(AppLocalizations l10n) {
    switch (level) {
      case AiDisclosureLevel.aiGenerated:
        return l10n.sharedAiGenerated;
      case AiDisclosureLevel.notHumanReviewed:
        return l10n.sharedAiNotReviewed;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome_rounded, size: 12, color: AppColors.info),
          const SizedBox(width: AppSpacing.xs),
          Text(
            _label(context.l10n),
            style: AppTextStyles.caption.copyWith(color: AppColors.info),
          ),
        ],
      ),
    );
  }
}
