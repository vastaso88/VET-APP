import 'package:flutter/material.dart';

import '../../../../design_system/atoms/outline_icon_button.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';
import '../../../../l10n/l10n.dart';

class PetsScaffold extends StatelessWidget {
  const PetsScaffold({
    required this.title,
    required this.body,
    super.key,
    this.subtitle,
    this.actions,
    this.onBack,
    this.badge,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final VoidCallback? onBack;
  final Widget body;

  /// Beside the back arrow: pass a [PetAvatar] on pages tied to one real pet
  /// (detail/edit) so the header shows its actual photo or initial.
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final titleText =
        Text(title, style: AppTextStyles.heading, maxLines: 2, overflow: TextOverflow.ellipsis);
    // A root page (no back arrow, no pet): the title and the action share a row.
    final titleInRow = onBack == null && badge == null;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppColors.backgroundGradient,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (onBack != null) ...[
                      OutlineIconButton(
                        tooltip: context.l10n.commonBack,
                        onPressed: onBack,
                        icon: Icons.arrow_back_rounded,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    if (badge != null) badge!,
                    if (titleInRow) Expanded(child: titleText) else const Spacer(),
                    if (actions != null) ...actions!,
                  ],
                ),
                if (!titleInRow) ...[
                  const SizedBox(height: AppSpacing.lg),
                  titleText,
                ],
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(subtitle!, style: AppTextStyles.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: AppSpacing.lg),
                Expanded(child: body),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
