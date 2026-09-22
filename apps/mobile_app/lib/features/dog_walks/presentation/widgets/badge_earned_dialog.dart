import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../walk_labels.dart';

/// Celebrates newly-unlocked badges right after a walk ends. This is the
/// in-app "animation on achievement" the user asked for; push
/// notifications are separate, undecided infrastructure (docs/maps/) and
/// are not part of this dialog.
Future<void> showBadgeEarnedDialog(BuildContext context, List<String> earnedBadgeIds) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Badge sbloccato',
    barrierColor: Colors.black.withValues(alpha: 0.5),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, _, __) => _BadgeEarnedDialog(badgeIds: earnedBadgeIds),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
      return ScaleTransition(
        scale: curved,
        child: FadeTransition(opacity: animation, child: child),
      );
    },
  );
}

class _BadgeEarnedDialog extends StatelessWidget {
  const _BadgeEarnedDialog({required this.badgeIds});

  final List<String> badgeIds;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.xl)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 500),
              curve: Curves.elasticOut,
              builder: (context, value, child) => Transform.scale(scale: value, child: child),
              child: Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: AppColors.accentSoft, shape: BoxShape.circle),
                child: const Icon(Icons.emoji_events_rounded, size: 36, color: AppColors.warning),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              badgeIds.length == 1 ? 'Nuovo badge sbloccato!' : 'Nuovi badge sbloccati!',
              style: AppTextStyles.title,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            for (final badgeId in badgeIds)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text(
                  badgeLabel(badgeId),
                  style: AppTextStyles.body.copyWith(color: AppColors.text, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Evviva!'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
