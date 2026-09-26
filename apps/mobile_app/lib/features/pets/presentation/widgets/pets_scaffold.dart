import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_text_styles.dart';

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

  /// Replaces the default paw+"Pet" pill — pass a [PetAvatar] on pages tied
  /// to one real pet (detail/edit) so the header shows its actual photo or
  /// initial instead of a generic icon.
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF4F8F5),
              Color(0xFFF8FBF8),
              Color(0xFFEAF2ED),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.md,
              AppSpacing.xl,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (onBack != null) ...[
                      IconButton(
                        onPressed: onBack,
                        icon: const Icon(Icons.arrow_back_rounded),
                        color: Colors.white,
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF163A35),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    badge ?? _defaultBadge(),
                    const Spacer(),
                    if (actions != null) ...actions!,
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(title, style: AppTextStyles.heading, maxLines: 2, overflow: TextOverflow.ellipsis),
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

  Widget _defaultBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.pets, size: 14, color: AppColors.accent),
          SizedBox(width: AppSpacing.sm),
          Text(
            'Pet',
            style: TextStyle(
              color: AppColors.onPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class RoundedSurface extends StatelessWidget {
  const RoundedSurface({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
    this.backgroundColor = AppColors.surface,
    this.borderColor = AppColors.border,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color backgroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12163A35),
            blurRadius: 24,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }
}
