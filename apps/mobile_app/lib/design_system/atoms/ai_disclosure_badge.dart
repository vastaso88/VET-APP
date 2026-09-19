import 'package:flutter/material.dart';

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

  String get _label {
    switch (level) {
      case AiDisclosureLevel.aiGenerated:
        return 'Generato da IA';
      case AiDisclosureLevel.notHumanReviewed:
        return 'Risposta automatica, non revisionata';
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
            _label,
            style: AppTextStyles.caption.copyWith(color: AppColors.info),
          ),
        ],
      ),
    );
  }
}
